# coding: utf-8
# This script is a part of DAsse(https://github.com/hisui/dasse)

require "pp"
require "rjquery"


##
## ニーモニックを表現するためのクラスたち
##

# オペランドを表現
class Operand
	attr_reader :size
	
end

# オペランドとなるレジスターを表現
class Reg < Operand
	@@register_map = {}
	attr_reader :name, :size, :half
	
	def initialize(name, size, half=nil)
		@@register_map[name] = self
		@name = name
		@size = size
		@half = half
	end
	
	def to_s
		@name.to_s
	end
	
	def self.get_by_name(name)
		@@register_map[name.downcase.intern]
	end

	def self.get(i, kind="G", size=4)
		case kind
		when "G"
			case size
			when 4 then
				case i
				when 0 then EAX
				when 1 then ECX
				when 2 then EDX
				when 3 then EBX
				when 4 then ESP
				when 5 then EBP
				when 6 then ESI
				when 7 then EDI
				end
			when 2
				case i
				when 0 then AX
				when 1 then CX
				when 2 then DX
				when 3 then BX
				when 4 then SP
				when 5 then BP
				when 6 then SI
				when 7 then DI
				end
			when 1
				case i
				when 0 then AL
				when 1 then CL
				when 2 then DL
				when 3 then BL
				when 4 then AH
				when 5 then CH
				when 6 then DH
				when 7 then BH
				end
			end
		when "C"
			raise
		when "S"
			case i
			when 0 then CS
			when 1 then DS
			when 2 then ES
			when 3 then FS
			when 4 then GS
			when 5 then SS
			end
		end
	end
	
	# 8-bit general purpose registers
	AH = Reg.new :ah, 8
	BH = Reg.new :bh, 8
	CH = Reg.new :ch, 8
	DH = Reg.new :dh, 8
	AL = Reg.new :al, 8
	BL = Reg.new :bl, 8
	CL = Reg.new :cl, 8
	DL = Reg.new :dl, 8
	
	# 16-bit general purpose registers
	AX = Reg.new :ax, 16, AH
	BX = Reg.new :bx, 16, BH
	CX = Reg.new :cx, 16, CH
	DX = Reg.new :dx, 16, DH
	SP = Reg.new :sp, 16
	BP = Reg.new :bp, 16
	SI = Reg.new :si, 16
	DI = Reg.new :di, 16
	
	# 32-bit general purpose registers
	EAX = Reg.new :eax, 32, AX
	EBX = Reg.new :ebx, 32, BX
	ECX = Reg.new :ecx, 32, CX
	EDX = Reg.new :edx, 32, DX
	ESP = Reg.new :esp, 32, SP
	EBP = Reg.new :ebp, 32, BP
	ESI = Reg.new :esi, 32, SI
	EDI = Reg.new :edi, 32, DI
	
	# segment registers
	CS = Reg.new :cs, 32
	DS = Reg.new :ds, 32
	ES = Reg.new :es, 32
	FS = Reg.new :fs, 32
	GS = Reg.new :gs, 32
	SS = Reg.new :ss, 32
	
	# FLAGS registers
	 FLAGS = Reg.new  :flags, 16
	EFLAGS = Reg.new :eflags, 32, FLAGS
	
	# XMM registers
	XMM0 = Reg.new :xmm0, 128
	XMM1 = Reg.new :xmm1, 128
	XMM2 = Reg.new :xmm2, 128
	XMM3 = Reg.new :xmm3, 128
	XMM4 = Reg.new :xmm4, 128
	XMM5 = Reg.new :xmm5, 128
	XMM6 = Reg.new :xmm6, 128
	XMM7 = Reg.new :xmm7, 128
	
end

# オペランドのメモリアドレスを表現
class Mem < Operand
	attr_reader :addr
	
	def initialize(addr)
		@addr = addr
	end
	
	def to_s
		"[#{addr}]"
	end
end

# オペランドの即値を表現
class Imm < Operand
	attr_reader :data
	
	def initialize(data)
		@data = data
	end
	
	def to_s
		@data.to_s
	end
end

# SIBを表現: reg1 + reg2*scale + disp
class SIB < Operand
	attr_reader :reg1, :reg2, :disp, :scale
	
	def initialize(reg1, reg2, scale=0, disp=0)
		@reg1  = reg1
		@reg2  = reg2
		@scale = scale
		@disp  = disp
	end
	
	def to_s
		buf =  "[#{reg1}"
		buf << "+#{reg2}*%d" % scale if scale != 0
		buf <<         "%+d" %  disp if  disp != 0
		buf << "]"
	end
end

# 逆アセンブルされたニーモニックを表現
class Mnemonic
	attr_accessor :code, :args
	
	def initialize(code, args)
		@code = code
		@args = args
	end
	
	def to_s
		code.name + " " + args.join(",")
	end
end



##
## 逆アセンブラのコア部分
##

# オペコードを表現
class Opcode
	attr_reader :name, :args, :use_mod_rm, :imm_size
	
	def initialize(name, args)
		#p [name]
		@name = name
		@args = args.map {|e| parse_arg e }
	end

	# 引数表記(Ivとか)を解析
	def parse_arg(arg)
		
		# 一般形式(モード:データサイズ)
		if arg =~/^([A-Z])([a-z])$/
			mode =      $1
			size = case $2
			when "a" then  0 # ?
			when "p" then  0 # ?
			when "s" then  0 # ?
			when "c" then -1 # byte or word
			when "v" then -2 # word or double word
			when "d" then  4 # double word
			when "w" then  2 # word
			when "b" then  1 # byte
			else
				raise Exception.new("(*_*) bug? $2=#{$2}")
			end
	
			return case mode
			# ダイレクトアドレス
			when "A"
				@imm_size = size
				-> ctx { Mem.new ctx.imm }
			# 即値とジャンプ先の相対オフセット
			when "I", "J" then
				@imm_size = size
				-> ctx { Imm.new ctx.imm }
			# コードのオフセットからデータを即値として参照(多分)
			when "O" then
				@imm_size = size # これ多分間違い。サイズはアドレスモードに合わせる必要があるはず
				-> ctx { Mem.new ctx.imm }
			# mod r/m の "r/m" 値を参照(M,Rは何だかよくわからん)
			when "E", "M", "R" then
				@use_mod_rm = true
				-> ctx { ctx.rm_value }
			# mod r/m の "reg" 値を参照
			when "C", "D", "G", "S", "T" then
				-> ctx { Reg.get(ctx.reg, mode, ctx.calc_real_address_size(size)) }
			# Flagsレジスタ
			when "F" then
				-> ctx { ctx.is_address_16bit ? Reg::FLAGS: Reg::EFLAGS }
			# よくわからない(あとで対応)
			when "X", "Y" then
				-> ctx { Imm.new "..." }
			end
		end
		
		# 特殊形式。INT(0xcc)のみっぽい
		if arg =~/^(\d+)$/
			n = $1.to_i
			return ->_ { Imm.new n }
		end
		
		# レジスタ名
		if reg = Reg.get_by_name(arg)
			# eXX is used when the width of the register depends on the operand size attribute
			if arg =~/^e..$/
				return -> ctx { ctx.is_16bit_mode ? reg.half: reg }
			end
			return ->_ { reg }
		end
		
		raise Exception.new("(*_*) bug? arg="+ arg)
	end
end

# ディスアセンブルを行う人
class DASM_x86
	#
	# 16-bitモードが有効かどうか
	# see 17.1.1 Default Segment Attribute
	#
	attr_accessor :off, :is_16bit_mode
	
	# prefixとバイトデータの対応表
	PREFIX_MAP = 
		{:@segment      => [0x2e,0x36,0x3e,0x26,0x64,0x65],
		 :@operand_size => [0x66],
		 :@address_size => [0x67],
		 :@bus_lock     => [0xf0],
		 :@rep_repne    => [0xf2,0xf3]}
		 
	# Opcodeの参照用
	attr_reader(
		*PREFIX_MAP.keys.map {|e| e[1..-1] },
		# mod r/m 関係
		:reg,
		:imm,
		:rm_value)

	def initialize(src, off=0)
		@src = src
		@off = off
	end
	
	def more?
		@off < @src.size
	end

	#
	# 属性値が16-bitモードに設定されているかどうか(アドレス)
	# see 17.1.2 Operand-Size and Address-Size Instruction Prefixes
	#
	def is_address_16bit
		b = @is_16bit_mode
		b = !b if @address_size
		b
	end

	#
	# 属性値が16-bitモードに設定されているかどうか(オペランド)
	# see 17.1.2 Operand-Size and Address-Size Instruction Prefixes
	#
	def is_operand_16bit
		b = @is_16bit_mode
		b = !b if @operand_size
		b
	end
	
	def walk

		# 各種prefixのちぇっく。一旦、内容をリセットする
		PREFIX_MAP.each {|key, _| instance_variable_set key, nil }
		loop {
			none = true
			PREFIX_MAP.each {|key, values|
				if values.include? get
					none = nil
					instance_variable_set key, get_and_inc
				end
			}
			break if none
		}

		# オペコードの種類を判別
		code = get_and_inc
		code = get_and_inc | 0x0f00 if code == 0x0f # 2-byte escape
		
		# オペコードマップから検索。なかったら死亡
		opcode = OPCODE_MAP[code] or
			raise RuntimeError.new("unknown opcode: %04x" % code)

		# mod r/m からオペランドを生成
		if opcode.is_a?(Integer) || opcode.use_mod_rm
			mod_rm = get_and_inc
			_rm = mod_rm & 0x07; mod_rm >>= 3
			reg = mod_rm & 0x07; mod_rm >>= 3
			mod = mod_rm & 0x03
			opcode.is_a?(Integer) and # グループの場合
				opcode = OPCODE_GRP[(opcode << 4) | reg]

			@rm_value = case
			# 32-bit Displacement-Only Mode
			when _rm == 5 && mod == 0 then Mem.new get_n(4)
			# SIB
			when _rm == 4 && mod == 0 then get_SIB 0
			when _rm == 4 && mod == 1 then get_SIB 1
			when _rm == 4 && mod == 2 then get_SIB 4
			else
				# general cases
				case mod
				when 0 then SIB.new(Reg.get(_rm), nil, 0)
				when 1 then SIB.new(Reg.get(_rm), nil, 0, get_n(1))
				when 2 then SIB.new(Reg.get(_rm), nil, 0, get_n(4))
				when 3 then Reg.get(_rm)
				end
			end
		end
		
		# 必要なら即値を読む
		if opcode.imm_size
			@imm = get_n calc_real_operand_size(opcode.imm_size)
		end
		@reg = reg

		Mnemonic.new(opcode, opcode.args.map {|e| e[self] })
	end
	
	def calc_real_operand_size(n)
		n > 0 ? n : is_operand_16bit ? -n : -n*2
	end
	
	def calc_real_address_size(n)
		n > 0 ? n : is_address_16bit ? -n : -n*2
	end
	
	def inc_and_get
		@src.getbyte(@off += 1)
	end
	
	def get_and_inc
		@src.getbyte @off
	ensure
		@off += 1
	end
	
	def get
		@src.getbyte @off
	end
	
	def get_n(n, signed=true)
		t = 0
		n.times {|i|
			t |= get_and_inc << i * 8 # little-endian
		}
		if signed && n > 0 && (t >> n * 8 - 1) != 0
			t |= -1 << n * 8
		end
		t
	end
	
	def get_SIB(disp)
		sib = get_and_inc
		SIB.new(
			Reg.get((sib & 0x07)),
			Reg.get((sib & 0x38) >> 3), 1 <<
				   ((sib & 0xc0) >> 6), get_n(disp))
	end
end



##
## HTML(./x86-opcode_map.html)の表データからオペコードマップを生成
##

OPCODE_MAP = {}
OPCODE_GRP = {}

def build_opcode_map(map, rows, modif)
	hi = 0
	rows.each {|tr|
		lo = -1
		tr.children[1..-1].each {|td|
			map[modif|hi|lo+=1] = case td.inner_text
			when /Grp#([\dA-F]+)/ then
				$1.hex
			when /([\w\/]+)((?:\s+\w+(?:\s*,\s*\w+)*)?)/ then
				Opcode.new $1, $2.split(/,/).map(&:strip)
			end
		}
		hi += 16
	}
end

doc = File.open(File.dirname(__FILE__) +
		"/x86-opcode_map.html", "r:UTF-8") {|io| RjQuery io.read }

build_opcode_map OPCODE_MAP, doc.find("#opcode_map1>tbody>tr"), 0
build_opcode_map OPCODE_MAP, doc.find("#opcode_map2>tbody>tr"), 0x0f00
build_opcode_map OPCODE_GRP, doc.find("#group_table>tbody>tr"), 0



