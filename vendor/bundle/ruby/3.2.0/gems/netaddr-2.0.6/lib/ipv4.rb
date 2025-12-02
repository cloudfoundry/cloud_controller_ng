module NetAddr
	
	#IPv4 represents a single IPv4 address. 
	class IPv4
		# addr is the Integer representation of this IP address
		attr_reader :addr
		
		#Create an IPv4 from an Integer. Must be between 0 and 2**32-1.
		#Throws ValidationError on error.
		def initialize(i)
			if (!i.kind_of?(Integer))
				raise ValidationError, "Expected an Integer for 'i' but got a #{i.class}."
			elsif ( (i < 0) || (i > 2**32-1) )
				raise ValidationError, "#{i} is out of bounds for IPv4."
			end
			@addr = i
		end
		
		# parse will create an IPv4 from its string representation (ie. "192.168.1.1").
		# Throws ValidationError on error.
		def IPv4.parse(ip)
			ip = ip.strip
			i = Util.parse_IPv4(ip)
			return IPv4.new(i)
		end
		
		#cmp compares equality with another IPv4. Return:
		#* 1 if this IPv4 is numerically greater
		#* 0 if the two are equal
		#* -1 if this IPv4 is numerically less
		def cmp(other)
			if (!other.kind_of?(IPv4))
				raise ArgumentError, "Expected an IPv4 object for 'other' but got a #{other.class}."
			end
			if (self.addr > other.addr)
				return 1
			elsif (self.addr < other.addr)
				return -1
			end
			return 0
		end
		
		# multicast_mac returns the EUI48 multicast mac-address for this IP.
		# It will return the zero address for IPs outside of the multicast range 224.0.0.0/4.
		def multicast_mac
			mac = 0
			if (@addr&0xf0000000 == 0xe0000000) # within 224.0.0.0/4 ?
				# map lower 23-bits of ip to 01:00:5e:00:00:00
				mac = (@addr&0x007fffff) | 0x01005e000000
			end
			return EUI48.new(mac)
		end
		
		# next returns the next consecutive IPv4 or nil if the address space is exceeded
		def next()
			if (self.addr == NetAddr::F32)
				return nil
			end
			return IPv4.new(self.addr + 1)
		end
		
		# prev returns the preceding IPv4 or nil if this is 0.0.0.0
		def prev()
			if (self.addr == 0)
				return nil
			end
			return IPv4.new(self.addr - 1)
		end
		
		# to_net returns the IPv4 as a IPv4Net
		def to_net()
			NetAddr::IPv4Net.new(self,nil)
		end
		
		# to_s returns the IPv4 as a String
		def to_s()
			Util.int_to_IPv4(@addr)
		end
		
		# version returns "4" for IPv4
		def version()
			return 4
		end
		
	end # end class IPv4
	
end # end module
