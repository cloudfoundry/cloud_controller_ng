module NetAddr
	
	# EUI64 (Extended Unique Identifier 64-bit, or EUI-64) represents a 64-bit hardware address.
	class EUI64
		
		# addr is the Integer representation of this EUI
		attr_reader :addr
		
		#Create an EUI64 from an Integer. Must be between 0 and 2**64-1.
		#Throws ValidationError on error.
		def initialize(i)
			if (!i.kind_of?(Integer))
				raise ValidationError, "Expected an Integer for 'i' but got a #{i.class}."
			elsif ( (i < 0) || (i > 2**64-1) )
				raise ValidationError, "#{i} is out of bounds for EUI64."
			end
			@addr = i
		end
		
		# Parse an EUI-64 string into an EUI64 type.
		# This will successfully parse most of the typically used formats such as:
		# * aa-bb-cc-dd-ee-ff-00-11
		# * aa:bb:cc:dd:ee:ff:00:11
		# * aabb.ccdd.eeff.0011
		# * aabbccddeeff0011
		# 
		# Although, in truth, its not picky about the exact format as long as
		# it contains exactly 16 hex characters with the optional delimiting characters
		# '-', ':', or '.'.
		def EUI64.parse(addr)
			addr = addr.strip.gsub(/[\-\:\.]/,"")
			if (addr.length != 16)
				raise ValidationError, "Must contain exactly 16 hex characters with optional delimiters."
			elsif (addr =~ /[^0-9a-fA-F\:]/)
				raise ValidationError, "#{addr} contains invalid characters."
			end
			return EUI64.new(addr.to_i(16))
		end
		
		# bytes returns a list containing each byte of the EUI64 as a String.
		def bytes()
			return [
				(@addr >> 56 & 0xff).to_s(16).rjust(2, "0"),
				(@addr >> 48 & 0xff).to_s(16).rjust(2, "0"),
				(@addr >> 40 & 0xff).to_s(16).rjust(2, "0"),
				(@addr >> 32 & 0xff).to_s(16).rjust(2, "0"),
				(@addr >> 24 & 0xff).to_s(16).rjust(2, "0"),
				(@addr >> 16 & 0xff).to_s(16).rjust(2, "0"),
				(@addr >> 8 & 0xff).to_s(16).rjust(2, "0"),
				(@addr & 0xff).to_s(16).rjust(2, "0"),
				]
		end
		
		# to_ipv6 generates an IPv6 address from this EUI64 address and the provided IPv6Net.
		# Nil will be returned if net is not a /64.
		def to_ipv6(net)
			if (!net.kind_of?(IPv6Net))
				raise ArgumentError, "Expected an IPv6Net object for 'net' but got a #{net.class}."
			end
			
			if (net.netmask.prefix_len != 64)
				return nil
			end
			
			# set u/l bit to 0
			hostId = @addr ^ 0x0200000000000000
			ipAddr = net.network.addr | hostId
			return IPv6.new(ipAddr)
		end
		
		def to_s()
			return self.bytes.join("-")
		end
		
	end # end class EUI64
	
end # end module
