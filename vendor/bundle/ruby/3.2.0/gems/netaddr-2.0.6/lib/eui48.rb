module NetAddr
	
	# EUI48 (Extended Unique Identifier 48-bit, or EUI-48) represents a 48-bit hardware address.
	# It is typically associated with mac-addresses.
	class EUI48
		
		# addr is the Integer representation of this EUI
		attr_reader :addr
		
		#Create an EUI48 from an Integer. Must be between 0 and 2**48-1.
		#Throws ValidationError on error.
		def initialize(i)
			if (!i.kind_of?(Integer))
				raise ValidationError, "Expected an Integer for 'i' but got a #{i.class}."
			elsif ( (i < 0) || (i > 2**48-1) )
				raise ValidationError, "#{i} is out of bounds for EUI48."
			end
			@addr = i
		end
		
		# Parse an EUI-48 string into an EUI48 type.
		# This will successfully parse most of the typically used formats such as:
		# * aa-bb-cc-dd-ee-ff
		# * aa:bb:cc:dd:ee:ff
		# * aabb.ccdd.eeff
		# * aabbccddeeff
		# 
		# Although, in truth, its not picky about the exact format as long as
		# it contains exactly 12 hex characters with the optional delimiting characters
		# '-', ':', or '.'.
		def EUI48.parse(addr)
			addr = addr.strip.gsub(/[\-\:\.]/,"")
			if (addr.length != 12)
				raise ValidationError, "Must contain exactly 12 hex characters with optional delimiters."
			elsif (addr =~ /[^0-9a-fA-F\:]/)
				raise ValidationError, "#{addr} contains invalid characters."
			end
			return EUI48.new(addr.to_i(16))
		end
		
		# bytes returns a list containing each byte of the EUI48 as String.
		def bytes()
			return [
				(@addr >> 40 & 0xff).to_s(16).rjust(2, "0"),
				(@addr >> 32 & 0xff).to_s(16).rjust(2, "0"),
				(@addr >> 24 & 0xff).to_s(16).rjust(2, "0"),
				(@addr >> 16 & 0xff).to_s(16).rjust(2, "0"),
				(@addr >> 8 & 0xff).to_s(16).rjust(2, "0"),
				(@addr & 0xff).to_s(16).rjust(2, "0"),
				]
		end
		
		
		# to_eui64 converts this EUI48 into an EUI64 by inserting 0xfffe between the first and last 24-bits of the address.
		def to_eui64()
			return EUI64.new((@addr & 0xffffff000000) << 16 | (@addr & 0x000000ffffff) | 0x000000fffe000000)
		end
		
		def to_s()
			return self.bytes.join("-")
		end
		
	end # end class EUI48
	
end # end module
