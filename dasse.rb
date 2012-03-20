# coding: utf-8

##
## DAsse - Disassembler for *.exe file
## (https://github.com/hisui/dasse)
##

require "optparse"
require "pp"

$:.unshift "./lib"
$:.unshift "./ext"
require "exefile"
require "x86"


#OptionParser.new do |opt|
#	opt.on('-b') {|v| p v }
#	opt.parse!(ARGV)
#end

if ARGV.empty?
	$stderr.puts "usage:ruby dasse.rb FILENAME"
	exit -1
end

filename = ARGV[0]
File.open(filename, "rb:ASCII-8BIT") {|io|
	exe = ExeImage.new io
	unless section = exe.get_section_header(".text")
		raise RuntimeError.new("`.text' section is not found!")
	end
	data = exe.get_section_contents ".text"
	dasm = DASM_x86.new data, 0
	while dasm.more?
		off = dasm.off
		mnemonic = dasm.walk
		printf("%08x: % 30s: %s\n",
				off + section.virtualAddress + exe.optional_header.imageBase,
				data[off...dasm.off].unpack("H*")[0].split(/(..)/).select{|e| e != ""}.join(" "),
				mnemonic.to_s)	
	end
}

