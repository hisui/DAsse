# coding: utf-8

##
## RjQuery - Simple HTML DOM Library with jQuery-like DOM Selector
## (https://github.com/hisui/rjquery)
##

require "strscan"
require "set"


# HTMLを解析する
class RjStAX
	attr_reader :scan, :node, :name, :attrs, :text

	def initialize(html)
		@scan = StringScanner.new html
	end

	def next_node       # 1                     2    3      4
		if @scan.scan %r{^((?:.*?(?:<!.*?>)?)*?)(<\s*(/)?\s*((?:\w+:)?\w+))}m
			unless @scan[1].empty?
				@text = RjStAX.decode @scan[1].strip
				@node = :text
				@scan.pos -= @scan[2].size
				return true
			end
			if @scan[4]
				@name = @scan[4].downcase
				if @scan[3].nil?
					@attrs = {}        #    1                    2      3
					while @scan.scan %r{^\s*([^\s/=>]+)(?:\s*=\s*(['"]?)((?=['"])(?=\2)|(?!\2).*?|[^\s>]*)\2)?}m
						@attrs[@scan[1]] = trim(@scan[3] || @scan[1])
					end
					if @scan.scan %r{^\s*(/)?\s*>}m
						@node = @scan[1] ? :empty : :open
						return true
					end
				elsif scan.scan /^\s*>/m
					@node = :close
					return true
				end
			end
		end
		unless scan.eos?
			@text = trim scan.rest
			@node = :text
			scan.clear
			return true
		end
		nil
	end
	
	def trim(text)
		RjStAX.decode(text.gsub(/\s+/, " "))
	end
	
	def self.encode(text)
		html = text.dup
		html.gsub! "&", "&amp;"
		html.gsub! "<", "&lt;"
		html.gsub! ">", "&gt;"
		html.gsub! "'", "&apos;"
		html.gsub! '"', "&quot;"
		html.gsub! " ", "&nbsp;"
		html
	end
	
	def self.decode(html)
		html.gsub(/&(?:(#\d+)|(.*?));/) {||
			return $1.to_i.chr if $1
			case $2
			when  "amp" then "&"
			when   "lt" then "<"
			when   "gt" then ">"
			when "apos" then "'"
			when "quot" then '"'
			when "nbsp" then " "
			else
				# raise RuntimeError.new("Unknown character entity: `#{$2}'.")
				"?" # エラーになるとウザいので・・・<(^_^;)
			end
		}
	end
end


# 要素の集合を表す
class RjNodeSet
	include Enumerable
	
	class ArraySet < RjNodeSet
		def initialize(list)
			@list = list
		end
		
		def each(&block)
			@list.each &block
		end
		
		def to_a
			@list.dup
		end
	end
	
	def self.from_a(a)
		a.size == 1 ? a[0]: ArraySet.new(a)
	end
	
	def method_missing(key, *args)
		first or raise NoMethodError.new("#{key}")
		first.__send__ key, args
	end
	
	def find(query)
		filter " #{query}"
	end
	
	def filter(query)
		scan = StringScanner.new query
		def scan.*(pattern)
			scan pattern
		end
		RjNodeSet.from_a eval_query(scan, to_a, /^$/)
	end
	
	# jQuery風のクエリを実行する
	# 参考: http://semooh.jp/jquery/api/selectors/
	def eval_query(scan, list, terminator)
		#p ["QUERY:", scan.rest, terminator]
		until scan.scan terminator
			# 検索範囲を限定
			case
			when scan * /^\s+/; # descendings
				done = Set.new list
				list.map! {|node| node.children }.flatten!
				list.each {|node|
					next if done.member? node
					done << node
					list.concat node.children
				}
			when scan * /^\+/; list.map! {|node| node.succ or[]}.flatten!
			when scan * /^\-/; list.map! {|node| node.prev or[]}.flatten!
			when scan * /^\>/; list.map! {|node| node.children }.flatten!
			when scan * /^\~/; list.map! {|node| node.siblings }.flatten!
				list.uniq! # {|node| node.object_id }
			end
			# フィルタリング
			loop {
				case
				when scan *      /^\*/; nil
				when scan * /^\.(\w+)/; list.select! {|node| node.attrs["class"] =~/\b#{scan[1]}\b/ }
				when scan * /^\#(\w+)/; list.select! {|node| node.attrs["id"] == scan[1] }
				when scan *   /^(\w+)/; list.select! {|node| node.name == scan[1] }
				when scan * /^:parent/; list.select! {|node| node.children.empty? }
				when scan *  /^:empty/; list.reject! {|node| node.children.empty? }
				# リスト操作タイプ
				when scan *        /^:first/; list = [list[ 0]] unless list.empty?
				when scan *         /^:last/; list = [list[-1]] unless list.empty?
				when scan *  /^:eq\((.*?)\)/; list = list[scan[1].to_i, 1] || []
				when scan *  /^:gt\((.*?)\)/; list.slice! scan[1].to_i..-1
				when scan *  /^:lt\((.*?)\)/; list.slice! 0 ..scan[1].to_i
				# 子要素フィルタ(要素インデックスと違って1-origin)
				when scan * /^:nth-child\((\d+)(n(?:\+(\d+))?)?\)/
					i = scan[1].to_i
					j = scan[3].to_i
					list.select! &(scan[2] ?
						-> node { (node.index+1) % i == j }:
						-> node {  node.index+1      == i })
				# 属性フィルタ
				when scan * /^\[(\w+)(?:([!^$*]?)=(.*?))?\]/;
					key = scan[1]
					val = scan[3]
					list.select! {|node| node.attrs[key] }
					case scan[2]
					when  ""; list.select! {|node| node.attrs[key] == val }
					when "!"; list.select! {|node| node.attrs[key] != val }
					when "^"; list.select! {|node| node.attrs[key] =~/^#{val}/  }
					when "$"; list.select! {|node| node.attrs[key] =~ /#{val}$/ }
					when "*"; list.select! {|node| node.attrs[key].include? val }
					end
				# 与えられた文字列を持つ要素を(σ・∀・)σｹﾞｯﾂ!!
				when scan * /^:contains\((.*?)\)/;
					list.select! {|node| node.inner_text.include? scan[1] }
				# 再帰するやつ(適当なのでなまら重い)
				when scan * /^:not\(/; list -= eval_query(scan, list.dup, /^\)/)
				when scan * /^:has\(/;
					pos = scan.pos
					list.reject! {|node|
						scan.pos = pos
						eval_query(scan, node.children.dup, /^\)/).empty?
					}
					eval_query(scan, [], /^\)/) if pos == scan.pos
				
				else break
				end
			}
		end
		list
	end
end


# HTMLの要素(タグ)を表現
class RjNode < RjNodeSet
	@@newline = ""
	@@tab     = ""
	attr_accessor :name, :attrs, :all, :parent

	def initialize(name, attrs={}, child=nil)
		def (@attrs = attrs.dup).to_s
			map {|key, val| " #{key}=\"#{RjStAX.encode(val)}\"" }.join ""
		end
		@name = name
		@all  = [] # TODO: linked list
		self << child if child
	end
	
	def method_missing(key, *args)
		@attrs[key.to_s] or raise NoMethodError.new("#{key}")
	end
	
	def each
		yield self
	end
	
	def children
		@tags_cache ||= @all.reject {|node| node.instance_of? RjTextNode }
	end
	
	def inner_text
		@text_cache ||= @all.map {|node| node.inner_text }.join
	end
	
	def inner_text=(text)
		@all.each {|e| e.parent = nil }
		@all = []
		self << text
	end
	
	def index
		parent and parent.children.index(self)
	end
	
	def succ; parent.children[index+1] rescue nil end
	def prev; parent.children[index-1] rescue nil end
	
	def siblings
		parent ? parent.children[(index+1)..-1]: []
	end
	
	def <<(child)
		case child
		when RjTextNode,
		     RjNode then
			child.parent.remove child if child.parent
			child.parent = nil
			@all << child
		when String then
			@all << RjTextNode.new(child)
		when Enumerable then
			child.each {|e| self << e }
		end
		make_cache_dirty
		self
	end
	
	def remove(child)
		child.parent == self or raise ArgumentError.new(child.to_s)
		child.parent  = nil
		unless @all.delete(child)
			raise Exception.new("(*_*) bug?")
		end
		make_cache_dirty
	end
	
	def to_s
		html = "<#{name}#{attrs}>" + @@newline
		lifo = [[0, self]]
		until lifo.empty?
			i, node = lifo.last
			if i >= node.all.size
				lifo.pop
				html += @@newline + @@tab * lifo.size + "</#{node.name}>"
				html += @@newline
				next
			end
			node = node.all[i]
			lifo.last[0] += 1
			html += @@tab * lifo.size
			if node.all.empty?
				html += node.instance_of?(RjTextNode) ?
						node.to_s: "<#{node.name}#{node.attrs}></#{node.name}>" + @@newline
				next
			end
			html += "<#{node.name}#{node.attrs}>"
			html += @@newline
			lifo << [0, node]
		end
		html
	end
	
	def inspect
		"<#{name} #{attrs}> ... </#{name}>"
	end
	
	def make_cache_dirty
		@tags_cache = nil
		@text_cache = nil
	end
end


class RjTextNode
	attr_accessor :parent

	def initialize(text)
		@text = text
	end
	
	def all
		[]
	end
	
	def inner_text
		@text
	end
	
	def to_s
		@html ||= RjStAX.encode(@text)
	end
	
	def inspect
		"text:#{@text.inspect}"
	end
end


# HTMLテキストからDOMを生成
def RjQuery(html)
	parser = RjStAX.new html
	lifo = []
	root = []
	while parser.next_node
		case parser.node
		when :text then
			lifo.last and (text = parser.text) != "" and
			lifo.last << RjTextNode.new(text)
		when :open, :empty then
			node = RjNode.new parser.name, parser.attrs || {}
			(lifo.last || root) << node
			lifo << node if parser.node == :open
		when :close then
			lifo.slice!(lifo.rindex {|node| parser.name == node.name }..-1) rescue nil
		end
	end
	RjNodeSet.from_a root
end

