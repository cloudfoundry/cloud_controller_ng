module NetAddr
	
	#Mask128 represents a 128-bit netmask. 
	class Mask128
		# mask is the Integer representation of this netmask
		attr_reader :mask

		# prefix_len is the Integer prefix length of this netmask
		attr_reader :prefix_len
		
		# Create a Mask128 from an Integer prefix length. Valid values are 0-128.
		# Throws ValidationError on error.
		def initialize(prefix_len)
			if (!prefix_len.kind_of?(Integer))
				raise ValidationError, "Expected an Integer for 'prefix_len' but got a #{prefix_len.class}."
			elsif ( (prefix_len < 0) || (prefix_len > 128) )
				raise ValidationError, "#{prefix_len} must be in the range of 0-128."
			end
			@prefix_len = prefix_len
			@mask = NetAddr::F128 ^ (NetAddr::F128 >> @prefix_len)
		end
		
		# parse will create an Mask128 from its string representation.
		# arguments:
		# * mask - String representing an netmask (ie. "/64").
		#
		# Throws ValidationError on error.
		def Mask128.parse(mask)
			mask = mask.strip
			if (mask.start_with?("/")) # cidr format
				mask = mask[1..-1] # remove "/"
			end
			return Mask128.new(Integer(mask))
		rescue ArgumentError
			raise ValidationError, "#{mask} is not valid integer."
		end
		
		#cmp compares equality with another Mask128. Return:
		#* 1 if this Mask128 is larger in capacity
		#* 0 if the two are equal
		#* -1 if this Mask128 is smaller in capacity
		def cmp(other)
			if (!other.kind_of?(Mask128))
				raise ArgumentError, "Expected an Mask128 object for 'other' but got a #{other.class}."
			end
			if (self.prefix_len < other.prefix_len)
				return 1
			elsif (self.prefix_len > other.prefix_len)
				return -1
			end
			return 0
		end
		
		#len returns the number of IP addresses in this network. This is only useful if you have a subnet
		# smaller than a /64 as it will always return 0 for prefixes <= 64.
		def len()
			if (self.prefix_len <= 64)
				return 0
			end
			return (self.mask ^ NetAddr::F128) + 1 # bit flip the netmask and add 1
		end
		
		# to_s returns the Mask128 as a String
		def to_s()
			return "/#{@prefix_len}"
		end
		
	end # end class Mask128
	
end # end module
