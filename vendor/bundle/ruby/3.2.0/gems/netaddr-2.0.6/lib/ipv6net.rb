module NetAddr
	
	#IPv6Net represents an IPv6 network. 
	class IPv6Net
		
		#arguments:
		#* ip - an IPv6 object
		#* m128 - a Mask128 object. will default to a /64 if nil
		def initialize(ip,m128)
			if (!ip.kind_of?(IPv6))
				raise ArgumentError, "Expected an IPv6 object for 'ip' but got a #{ip.class}."
			elsif (m128 != nil && !m128.kind_of?(Mask128))
				raise ArgumentError, "Expected a Mask128 object for 'm128' but got a #{m128.class}."
			end
			
			if (m128 == nil)
				if (ip.addr != 0)
					m128 = Mask128.new(64) # use /64 mask per rfc 4291
				else
					m128 = Mask128.new(128) # use /128 mask per rfc 4291
				end
			end
			@m128 = m128
			@base = IPv6.new(ip.addr & m128.mask)
		end
		
		# parse will create an IPv6Net from its string representation. A default netmask will be used if not specified.
		# Throws ValidationError on error.
		def IPv6Net.parse(net)
			m128 = nil
			net = net.strip
			if (net.include?("/")) # cidr format
				addr,mask = net.split("/")
				m128 = Mask128.parse(mask)
			else
				addr = net
			end
			ip = IPv6.parse(addr)
			return IPv6Net.new(ip,m128)
		end
		
		# cmp compares equality with another IPv6Net. Return:
		# * 1 if this IPv6Net is numerically greater
		# * 0 if the two are equal
		# * -1 if this IPv6Net is numerically less
		#
		# The comparison is initially performed on using the cmp() method of the network address, however, in cases where the network
		# addresses are identical then the netmasks will be compared with the cmp() method of the netmask. 
		def cmp(other)
			if (!other.kind_of?(IPv6Net))
				raise ArgumentError, "Expected an IPv6Net object for 'other' but got a #{other.class}."
			end
			cmp = self.network.cmp(other.network)
			if (cmp != 0)
				return cmp
			end
			return self.netmask.cmp(other.netmask)
		end
		
		#contains returns true if the IPv6Net contains the IPv6
		def contains(ip)
			if (!ip.kind_of?(IPv6))
				raise ArgumentError, "Expected an IPv6 object for 'ip' but got a #{ip.class}."
			end
			if (@base.addr == ip.addr & @m128.mask)
				return true
			end
			return false
		end
		
		# fill returns a copy of the given Array, stripped of any networks which are not subnets of this IPv6Net
		# and with any missing gaps filled in.
		def fill(list)
			list = Util.filter_IPv6Net(list)
			return Util.fill(self,list)
		end
		
		#len returns the number of IP addresses in this network. It will return 0 for /0 networks.
		def len()
			return self.netmask.len
		end
		
		# long returns the IPv6Net as a string in long (uncompressed) format
		def long()
			return @base.long() + @m128.to_s
		end
		
		# netmask returns the Mask128 object representing the netmask for this network
		def netmask()
			@m128
		end
			
		# network returns the IPv6 object representing the network address
		def network()
			@base
		end
		
		# next returns the next largest consecutive IP network or nil if the end of the address space is reached.
		def next()
			net = self.nth_next_sib(1)
			if (!net)
				return nil
			end
			return net.grow
		end
		
		# next_sib returns the network immediately following this one or nil if the end of the address space is reached.
		def next_sib()
			self.nth_next_sib(1)
		end
		
		# nth returns the IPv6 at the given index.
		# The size of the network may be determined with the len() method.
		# If the range is exceeded then return nil.
		def nth(index)
			if (!index.kind_of?(Integer))
				raise ArgumentError, "Expected an Integer for 'index' but got a #{index.class}."
			elsif (self.netmask.prefix_len < 64 || (self.netmask.prefix_len > 64 && index >= self.len))
				return nil
			end
			return IPv6.new(self.network.addr + index)
		end
		
		# nth_subnet returns the subnet IPv6Net at the given index.
		# The number of subnets may be determined with the subnet_count() method.
		# If the range is exceeded  or an invalid prefix_len is provided then return nil.
		def nth_subnet(prefix_len,index)
			count = self.subnet_count(prefix_len)
			if (count == 0 || index >= count)
				return nil
			end
			sub0 = IPv6Net.new(self.network, Mask128.new(prefix_len))
			return sub0.nth_next_sib(index)
		end
		
		# prev returns the previous largest consecutive IP network or nil if this is ::.
		def prev()
			net = self.grow
			return net.prev_sib
		end
		
		# prev_sib returns the network immediately preceding this one or nil if this network is ::.
		def prev_sib()
			if (self.network.addr == 0)
				return nil
			end
			
			shift = 128 - self.netmask.prefix_len
			addr = ((self.network.addr>>shift) - 1) << shift
			if addr < 0
				return nil
			end
			return IPv6Net.new(IPv6.new(addr), self.netmask)
		end
		
		# rel determines the relationship to another IPv6Net. Returns:
		# * 1 if this IPv6Net is the supernet of other
		# * 0 if the two are equal
		# * -1 if this IPv6Net is a subnet of other
		# * nil if the networks are unrelated
		def rel(other)
			if (!other.kind_of?(IPv6Net))
				raise ArgumentError, "Expected an IPv6Net object for 'other' but got a #{other.class}."
			end
			
			# when networks are equal then we can look exlusively at the netmask
			if (self.network.addr == other.network.addr)
				return self.netmask.cmp(other.netmask)
			end
			
			# when networks are not equal we can use hostmask to test if they are
			# related and which is the supernet vs the subnet
			hostmask = self.netmask.mask ^ NetAddr::F128
			otherHostmask = other.netmask.mask ^ NetAddr::F128
			if (self.network.addr|hostmask == other.network.addr|hostmask)
				return 1
			elsif (self.network.addr|otherHostmask == other.network.addr|otherHostmask)
				return -1
			end
			return nil
		end
		
		# resize returns a copy of the network with an adjusted netmask.
		# Throws ValidationError on invalid prefix_len.
		def resize(prefix_len)
			m128 = Mask128.new(prefix_len)
			return IPv6Net.new(self.network,m128)
		end
		
		# subnet_count returns the number a subnets of a given prefix length that this IPv6Net contains.
		# It will return 0 for invalid requests (ie. bad prefix or prefix is shorter than that of this network).
		# It will also return 0 if the result exceeds the capacity of a 128-bit integer (ie. if you want the # of /128 a /0 will hold)
		def subnet_count(prefix_len)
			if (prefix_len <= self.netmask.prefix_len || prefix_len > 128 || prefix_len - self.netmask.prefix_len >= 128)
				return 0
			end
			return 1 << (prefix_len - self.netmask.prefix_len)
		end
		
		# summ creates a summary address from this IPv6Net and another.
		# It returns nil if the two networks are incapable of being summarized.
		def summ(other)
			if (!other.kind_of?(IPv6Net))
				raise ArgumentError, "Expected an IPv6Net object for 'other' but got a #{other.class}."
			end
			
			# netmasks must be identical
			if (self.netmask.prefix_len != other.netmask.prefix_len)
				return nil
			end
			
			# merge-able networks will be identical if you right shift them by the number of bits in the hostmask + 1
			shift = 128 - self.netmask.prefix_len + 1
			addr = self.network.addr >> shift
			otherAddr = other.network.addr >> shift
			if (addr != otherAddr)
				return nil
			end
			return self.resize(self.netmask.prefix_len - 1)
		end
		
		# to_s returns the IPv6Net as a String
		def to_s()
			return @base.to_s + @m128.to_s
		end
		
		# version returns "6" for IPv6
		def version()
			return 6
		end
		
		
		protected

		# grow decreases the prefix length as much as possible without crossing a bit boundary.
		def grow()
			addr = self.network.addr
			mask = self.netmask.mask
			prefix_len = self.netmask.prefix_len
			self.netmask.prefix_len.downto(0) do
				mask = (mask << 1) & NetAddr::F128
				if addr|mask != mask || prefix_len == 0 # // bit boundary crossed when there are '1' bits in the host portion
					break
				end
				prefix_len -= 1
			end
			
			return IPv6Net.new(IPv6.new(addr),Mask128.new(prefix_len))
		end
		
		# nth_next_sib returns the nth next sibling network or nil if address space exceeded.
		def nth_next_sib(nth)
			if (nth < 0)
				return nil
			end
			
			shift = 128 - self.netmask.prefix_len
			addr = ((self.network.addr>>shift) + nth) << shift
			if addr > NetAddr::F128
				return nil
			end
			return IPv6Net.new(IPv6.new(addr), self.netmask)
		end

	end # end class IPv6Net
	
end # end module
