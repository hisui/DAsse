# coding: utf-8
# This script is a part of DAsse(https://github.com/hisui/dasse)

POD_MEMBER_TYPES = {}

def pod_member(name, size=nil, pack=nil)
	unless type = POD_MEMBER_TYPES[name]
		   type = POD_MEMBER_TYPES[name] = Object.new
		type.singleton_class.instance_eval {
			define_method(:name) { name }
			define_method(:size) { size } if size
			define_method(:pack) { pack } if pack ||= size
		}
	end
	type
end

class << pod_member(:char, 1)
	def decode(io, array_n)
		io.read(array_n || 1)
	end
	
	def encode(io, array_n, value)
		io.write((d = (array_n || 1) - value.size) >= 0 ?
				value + "\0" * d : value[0...d]) # truncates!
	end
end

def make_decoder(&decode)
	lambda {|io, array_n|
		array_n ? (1..array_n).map { decode[io, nil] }: decode[io, nil]
	}
end

def make_encoder(&encode)
	lambda {|io, array_n, value|
		return encode[io, nil, value] unless array_n
		[value.size, array_n].min.times {|j|
			encode[io, nil, value[j]]
		}
		if value.size < array_n
			io.write("\0" * size * (array_n - value.size))
		end
	}
end

# defines big-endian numeric types: uiXX, siXX (XX=8*2^n, n=0..3)
1.times {

	4.times {|pow|
		size = 2 ** pow
		uiXX = pod_member("ui#{8 * size}".intern, size)
		uiXX.singleton_class.instance_eval {
			
			define_method(:decode, &make_decoder {|io, _|
				io.read(size).reverse. # reads as little-endin
				each_byte.reduce {|acc, e| acc << 8 | e }
			})
			
			define_method(:encode, &make_encoder {|io, _, value|
				size.times {|n| io.putc (value >> 8 * n) & 0xff }
			})
		}
		siXX = pod_member("si#{8 * size}".intern, size)
		siXX.singleton_class.instance_eval {
			mask = (1 << 8 * size) - 1

			define_method(:decode, &make_decoder {|io, _|
				t = uiXX.decode io, nil
				t = -((~t & mask) + 1) if (t >> 8 * size - 1) != 0 # 2's complement
				t
			})
			
			define_method(:encode, &make_encoder {|io, _, value|
				uiXX.encode io, nil, value & mask
			})
		}
	}
}

def def_pod(tag, &fn)
	if POD_MEMBER_TYPES.key? tag
		raise RuntimeError.new "duplicated POD name: `#{tag}'."
	end
	# setups DSL environment for fn
	pod = []
	env = Object.new
	env.singleton_class.instance_eval {
		POD_MEMBER_TYPES.each {|tag, type|
			define_method(tag) {|name, array_n=nil| pod << [name, array_n, type] }
		}
	}
	env.instance_eval &fn
	pack = pod.map {|*_, type| type.pack }.max
	size = 0
	pod.each {|_, array_n, type|
		size += size % type.pack + type.size * (array_n || 1)
	}
	size += size % pack
	# creates POD module
	mod = Class.new
	mod.instance_eval {
		pod.each {|name, *_| attr_accessor name }
		
		define_method(:__decode__) {|io|
			off = io.pos
			pod.each {|name, array_n, type|
				io.pos += (io.pos - off) % type.pack # align
				instance_variable_set("@" + name.to_s, type.decode(io, array_n))
			}
			io.pos += (io.pos - off) % pack
		}
		
		define_method(:__encode__) {|io|
			off = io.pos
			pod.each {|name, array_n, type|
				io.write "\0" * ((io.pos - off) % type.pack) # padding for data alignment
				sum += type.size
				type.encode(io, array_n, instance_variable_get("@#{name}"))
			}
			io.write "\0" * ((io.pos - off) % pack)
		}
		
		define_method(:inspect) {
			"#<pod " + pod.map {|name, *_| "#{name}=" +
					instance_variable_get("@#{name}").inspect }.join(", ") + ">"
		}
		
		define_method(:__size__) { size }
	}
	pod_member(tag, mod.new.__size__,  pack).singleton_class.instance_eval {
		define_method(:decode, &make_decoder {|io, _|
			value = mod.new
			value.__decode__(io)
			value
		})
		
		define_method(:encode, &make_encoder {|io, _, value|
			value.__encode__(io)
		})
	}
	mod
end



