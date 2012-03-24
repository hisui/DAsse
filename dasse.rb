# coding: utf-8

##
## DAsse - Disassembler for *.exe file
## (https://github.com/hisui/dasse)
##

require "optparse"
require "pp"

$:.unshift "#{File.dirname(__FILE__)}/lib"
$:.unshift "#{File.dirname(__FILE__)}/ext"
require "exefile"
require "x86"

$dasse_config = {
	     cpu_arch: "x86",
	  file_format: "exe",
	  show_offset: true,
	show_hex_dump: true,
}

OptionParser.new {|opt|
	opt.on("-f [VAL]") {|v| $dasse_config[:file_format] = v }
	opt.on("-a [VAL]") {|v| $dasse_config[:cpu_arch]    = v }
	opt.parse! ARGV
}

if ARGV.empty?
	$stderr.puts "You must specify a file."
	exit -1
end

data_offset = 0
data = File.open(ARGV[0], "rb:ASCII-8BIT") {|io|
	case $dasse_config[:file_format]
	when "raw" then io.read
	when "exe" then
		exe = ExeImage.new io
		unless section = exe.get_section_header(".text")
			raise RuntimeError.new("`.text' section is not found!")
		end
		# 多分、コレでいいはず・・・
		data_offset = section.virtualAddress + exe.optional_header.imageBase
		exe.get_section_contents ".text"
	else
		$stderr.puts "Unknown type of file_format=`#{$dasse_config[:file_format]}'."
		exit -1
	end
}

decoder = case $dasse_config[:cpu_arch]
when "x86" then DASM_x86.new data
when "raw" then
	class DefaultDecoder
		attr_reader :pos
		def initialize(src)
			@src = src
			@pos = 0
		end
		
		def more?
			@pos < @src.size
		end
		
		def walk
			slice = @src[@pos, 8]
			slice.bytes.map {|b|
				33 <= b && b <= 126 ? b.chr: "."
			}.join " "
		ensure
			@pos += 8
		end
	end
	DefaultDecoder.new data
else
	$stderr.puts "Unknown type of cpu_arch=`#{$dasse_config[:cpu_arch]}'."
	exit -1
end

while decoder.more?
	pos = decoder.pos
	col = decoder.walk
	if $dasse_config[:show_offset]
		printf "%08x: ", pos + data_offset
	end
	if $dasse_config[:show_hex_dump]
		printf "% 30s: ", data[pos...decoder.pos].bytes.map{|b| "%02x" % b}.join(" ")
	end
	puts col.to_s
end


