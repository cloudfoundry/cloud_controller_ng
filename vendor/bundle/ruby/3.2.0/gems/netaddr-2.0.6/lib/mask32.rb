module NetAddr
	
	#Mask32 represents a 32-bit netmask. 
	class Mask32
		# mask is the Integer representation of this netmask
		attr_reader :mask
		
		# prefix_len is the Integer prefix length of this netmask
		attr_reader :prefix_len
		
		# Create a Mask32 from an Integer prefix length. Valid values are 0-32.
		# Throws ValidationError on error.
		def initialize(prefix_len)
			if (!prefix_len.kind_of?(Integer))
				raise ValidationError, "Expected an Integer for 'prefix_len' but got a #{prefix_len.class}."
			elsif ( (prefix_len < 0) || (prefix_len > 32) )
				raise ValidationError, "#{prefix_len} must be in the range of 0-32."
			end
			@prefix_len = prefix_len
			@mask = NetAddr::F32 ^ (NetAddr::F32 >> @prefix_len)
		end
		
		# parse will create an Mask32 from its string representation.
		# arguments:
		#	* mask - String representing a netmask (ie. "/24" or "255.255.255.0").
		#
		#	Throws ValidationError on error.
		def Mask32.parse(mask)
			mask = mask.strip
			if (mask.start_with?("/")) # cidr format
				mask = mask[1..-1] # remove "/"
			end

			if (!mask.include?("."))
				begin
					return Mask32.new(Integer(mask))
				rescue ArgumentError
					raise ValidationError, "#{mask} is not valid integer."
				end
			end
			
			# for extended netmask
			# determine length of netmask by cycling through bit by bit and looking
			# for the first '1' bit, tracking the length as we go. we also want to verify
			# that the mask is valid (ie. not something like 255.254.255.0). we do this
			# by creating a hostmask which covers the '0' bits of the mask. once we have
			# separated the net vs host mask we xor them together. the result should be that
			# all bits are now '1'. if not then we know we have an invalid netmask.
			maskI = Util.parse_IPv4(mask)
			prefix = 32
			hostmask = 1
			i = maskI 
			32.downto(1) do
				if (i&1 == 1)
					hostmask = hostmask >> 1
					if (maskI ^hostmask != NetAddr::F32)
						raise ValidationError, "#{mask} is invalid. It contains '1' bits in its host portion."
					end
					break
				end
				hostmask = (hostmask << 1) | 1
				i = i>>1
				prefix -= 1
			end
			return Mask32.new(prefix)
			
		end
		
		# extended returns the Mask32 in extended format (eg. x.x.x.x)
		def extended()
			Util.int_to_IPv4(@mask)
		end
		
		#cmp compares equality with another Mask32. Return:
		#* 1 if this Mask128 is larger in capacity
		#* 0 if the two are equal
		#* -1 if this Mask128 is smaller in capacity
		def cmp(other)
			if (!other.kind_of?(Mask32))
				raise ArgumentError, "Expected an Mask32 object for 'other' but got a #{other.class}."
			end
			if (self.prefix_len < other.prefix_len)
				return 1
			elsif (self.prefix_len > other.prefix_len)
				return -1
			end
			return 0
		end
		
		#len returns the number of IP addresses in this network. It will always return 0 for /0 networks.
		def len()
			if (self.prefix_len == 0)
				return 0
			end
			return (self.mask ^ NetAddr::F32) + 1 # bit flip the netmask and add 1
		end
		
		# to_s returns the Mask32 as a String
		def to_s()
			return "/#{@prefix_len}"
		end
		
	end # end class Mask32
	
end # end module
