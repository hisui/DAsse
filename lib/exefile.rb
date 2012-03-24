# coding: utf-8
# This script is a part of DAsse(https://github.com/hisui/DAsse)

require "poddsl"
require "pp"


IMAGE_NUMBEROF_DIRECTORY_ENTRIES = 16


DOSHeader = def_pod(:IMAGE_DOS_HEADER) {

	char :e_magic, 2
	ui16 :e_cblp
	ui16 :e_cp
	ui16 :e_crlc
	ui16 :e_cparhdr
	ui16 :e_minalloc
	ui16 :e_maxalloc
	ui16 :e_ss
	ui16 :e_sp
	ui16 :e_csum
	ui16 :e_ip
	ui16 :e_cs
	ui16 :e_lfarlc
	ui16 :e_ovno
	ui16 :e_res, 4
	ui16 :e_oemid
	ui16 :e_oeminfo
	ui16 :e_res2, 10
	ui32 :e_lfanew

}

FileHeader = def_pod(:IMAGE_FILE_HEADER) {
	
	ui16 :machine
	ui16 :numberOfSections
	ui32 :timeDateStamp
	ui32 :pointerToSymbolTable
	ui32 :numberOfSymbols
	ui16 :sizeOfOptionalHeader
	ui16 :characteristics

}

DataDirectory = def_pod(:IMAGE_DATA_DIRECTORY) {
	ui32 :virtualAddress
	ui32 :size
}

OptionalHeader32 = def_pod(:IMAGE_OPTIONAL_HEADER32) {
	
	# Standard fields
	char :magic, 2
	ui8 :majorLinkerVersion
	ui8 :minorLinkerVersion
	ui32 :sizeOfCode
	ui32 :sizeOfInitializedData
	ui32 :sizeOfUninitializedData
	ui32 :addressOfEntryPoint
	ui32 :baseOfCode
	ui32 :baseOfData
	
	# NT additional fields
	ui32 :imageBase
	ui32 :sectionAlignment
	ui32 :fileAlignment
	ui16 :majorOperatingSystemVersion
	ui16 :minorOperatingSystemVersion
	ui16 :majorImageVersion
	ui16 :minorImageVersion
	ui16 :majorSubsystemVersion
	ui16 :minorSubsystemVersion
	ui32 :win32VersionValue
	ui32 :sizeOfImage
	ui32 :sizeOfHeaders
	ui32 :checksum
	ui16 :subsystem
	ui16 :dllCharacteristics
	ui32 :sizeOfStackReverse
	ui32 :sizeOfStackCommit
	ui32 :sizeOfHeapReverse
	ui32 :sizeOfHeapCommit
	ui32 :loaderFlags
	ui32 :numberOfRvaAndSizes
	IMAGE_DATA_DIRECTORY :dataDirectory, 16

}

SectionHeader = def_pod(:IMAGE_SECTION_HEADER) {
	char :name, 8
	# TODO
	#union(:misc) {
	#	ui32 :physicalAddress
	#	ui32 :virtualSize
	#}
	ui32 :virtualSize
	ui32 :virtualAddress
	ui32 :sizeOfRawData
	ui32 :pointerToRawData
	ui32 :pointerToRelocations
	ui32 :pointerToLinenumbers
	ui16 :numberOfRelocations
	ui16 :numberOfLinenumbers
	ui32 :characteristics
}


# exeファイルを解析＆表現
class ExeImage
	attr_reader :dos_header, :file_header, :optional_header
	
	def initialize(io)
		@io = io
		if lookahead(2) == "MZ" # IMAGE_DOS_HEADER
			@dos_header = DOSHeader.new
			@dos_header.__decode__(io)
			io.pos = dos_header.e_lfanew
		end
		if io.read(4) != "PE\0\0" # ensures that IMAGE_NT_HEADERS32 represents here
			raise RuntimeError.new("cannot find PE header!")
		end
		@file_header = FileHeader.new
		@file_header.__decode__(io)
		if @file_header.sizeOfOptionalHeader > 0
			case lookahead(2)
			when "\x0b\x01" # PE32
				@optional_header = OptionalHeader32.new
				@optional_header.__decode__(io)
			when "\x02\x0b" # PE+
				@optional_header = OptionalHeader32.new
				@optional_header.__decode__(io)
			when "\x01\x07" # ROM
				raise RuntimeError.new(
					"sizeOfOptionalHeader='ROM' is unsupported yet!")
			end
		end
		@section_headers = Hash[*(0...@file_header.numberOfSections).flat_map {
			section = SectionHeader.new
			section.__decode__(io)
			section.name.rstrip!
			next section.name, section
		}]
	end
	
	def section_names
		@section_headers.keys
	end
	
	def get_section_header(name)
		@section_headers[name]
	end
	
	def get_section_contents(name)
		section = get_section_header name
		unless section
			raise RuntimeError.new("no section named: `#{name}'.")
		end
		return nil if section.pointerToRawData == 0
		@io.pos = section.pointerToRawData
		@io.read section.virtualSize
	end
	
	def lookahead(n)
		if str = @io.read(n)
			@io.pos -= str.bytesize
		end
		str
	end
end



