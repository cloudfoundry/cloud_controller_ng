module NetAddr
	
	# Contains various internal util functions
	class Util
	private
	
	# backfill generates subnets between given IPv4Net/IPv6Net and the limit address.
	# limit should be < ipnet. will create subnets up to and including limit.
	def Util.backfill(ipnet,limit)
		nets = []
		cur = ipnet
		while true do
			net = cur.prev
			if (net == nil || net.network.addr < limit)
				break
			end
			nets.unshift(net)
			cur = net
		end
		return nets
	end
	
	
	# discard_subnets returns a copy of the IPv4NetList with any entries which are subnets of other entries removed.
	def Util.discard_subnets(list)
		keepers = []
		last = list[list.length-1]
		keep_last = true
		list.each do |net|
			rel = last.rel(net)
			if (!rel) # keep unrelated nets
				keepers.push(net)
			elsif (rel == -1) # keep supernets, but do not keep last
				keepers.push(net)
				keep_last = false
			end
		end
		
		# recursively clean up keepers
		if (keepers.length > 0)
			keepers = discard_subnets(keepers)
		end
		if keep_last
			keepers.unshift(last)
		end
		return keepers
	end
	
	# fill returns a copy of the given Array, stripped of any networks which are not subnets of ipnet
	# and with any missing gaps filled in.
	def Util.fill(ipnet,list)
		# sort & get rid of non subnets
		subs = []
		discard_subnets(list).each do |sub|
			r = ipnet.rel(sub)
			if (r == 1)
				subs.push(sub)
			end
		end
		subs = quick_sort(subs)
		
		filled = []
		if (subs.length > 0)
			# bottom fill if base missing
			base = ipnet.network.addr
			if (subs[0].network.addr != base)
				filled = backfill(subs[0],base)
			end
			
			# fill gaps between subnets
			0.upto(subs.length-1) do |i|
				sub = subs[i]
				if (i+1 < subs.length)
					filled.concat( fwdfill(sub,ipnet,subs[i+1]) )
				else
					filled.concat( fwdfill(sub,ipnet,nil) )
				end
			end
		end
		return filled
	end
	
	# filter_IPv4 returns a copy of list with only IPv4 objects
	def Util.filter_IPv4(list)
		filtered = []
		list.each do |ip|
			if (ip.kind_of?(IPv4))
				filtered.push(ip)
			end
		end
		return filtered
	end
	
	# filter_IPv4Net returns a copy of list with only IPv4Net objects
	def Util.filter_IPv4Net(list)
		filtered = []
		list.each do |ip|
			if (ip.kind_of?(IPv4Net))
				filtered.push(ip)
			end
		end
		return filtered
	end
	
	# filter_IPv6 returns a copy of list with only IPv6 objects
	def Util.filter_IPv6(list)
		filtered = []
		list.each do |ip|
			if (ip.kind_of?(IPv6))
				filtered.push(ip)
			end
		end
		return filtered
	end
	
	# filter_IPv6Net returns a copy of list with only IPv4Net objects
	def Util.filter_IPv6Net(list)
		filtered = []
		list.each do |ip|
			if (ip.kind_of?(IPv6Net))
				filtered.push(ip)
			end
		end
		return filtered
	end
	
	# fwdfill returns subnets between given IPv4Net/IPv6Nett and the limit address. limit should be > ipnet.
	def Util.fwdfill(ipnet,supernet,limit)
		nets = [ipnet]
		cur = ipnet
		if (limit != nil) # if limit, then fill gaps between net and limit
			while true do
				nextSub = cur.next()
				# ensure we've not exceed the total address space
				if (nextSub == nil)
					break
				end
				# ensure we've not exceeded the address space of supernet
				if (supernet.rel(nextSub) == nil)
					break
				end
				# ensure we've not hit limit
				if (nextSub.network.addr == limit.network.addr)
					break
				end
				
				# check relationship to limit
				if (nextSub.rel(limit) != nil) # if related, then nextSub must be a supernet of limit. we need to shrink it.
					prefixLen = nextSub.netmask.prefix_len
					while true do
						prefixLen += 1
						if (nextSub.kind_of?(IPv4Net))
							nextSub = IPv4Net.new(nextSub.network, Mask32.new(prefixLen))
						else
							nextSub = IPv6Net.new(nextSub.network, Mask128.new(prefixLen))
						end
						if (nextSub.rel(limit) == nil) # stop when we no longer overlap with limit
							break
						end
					end
				else # otherwise, if unrelated then grow until we hit the limit
					prefixLen = nextSub.netmask.prefix_len
					mask = nextSub.netmask.mask
					while true do
						prefixLen -= 1
						if (prefixLen == supernet.netmask.prefix_len) # break if we've hit the supernet boundary
							break
						end
						mask = mask << 1
						if (nextSub.network.addr|mask != mask) # break when bit boundary crossed (there are '1' bits in the host portion)
							break
						end
						if (nextSub.kind_of?(IPv4Net))
							grown = IPv4Net.new(nextSub.network, Mask32.new(prefixLen))
						else
							grown = IPv6Net.new(nextSub.network, Mask128.new(prefixLen))
						end
						if (grown.rel(limit) != nil) # if we've overlapped with limit in any way, then break
							break
						end
						nextSub = grown
					end
				end
				nets.push(nextSub)
				cur = nextSub
			end
		else # if no limit, then get next largest sibs until we've exceeded supernet
			while true do
				nextSub = cur.next()
				# ensure we've not exceed the total address space
				if (nextSub == nil)
					break
				end
				# ensure we've not exceeded the address space of supernet
				if (supernet.rel(nextSub) == nil)
					break
				end
				nets.push(nextSub)
				cur = nextSub
			end
		end
		return nets
	end
	
	# int_to_IPv4 converts an Integer into an IPv4 address String
	def Util.int_to_IPv4(i)
		octets = []
		3.downto(0) do |x|
			octet = (i >> 8*x) & 0xFF 
			octets.push(octet.to_s)
		end
		return octets.join('.')
	end
	
	# parse_IPv4 parses an IPv4 address String into an Integer
	def Util.parse_IPv4(ip)
	# check that only valid characters are present
		if (ip =~ /[^0-9\.]/)
			raise ValidationError, "#{ip} contains invalid characters."
		end
		
		octets = ip.strip.split('.')
		if (octets.length != 4)
			raise ValidationError, "IPv4 requires (4) octets."
		end

		ipInt = 0
		i = 4
		octets.each do |octet|
			octetI = octet.to_i()
			if ( (octetI < 0) || (octetI >= 256) )
				raise ValidationError, "#{ip} is out of bounds for IPv4."
			end
			i -= 1 
			ipInt = ipInt | (octetI << 8*i)
		end
		return ipInt
	end
	
	# parse_IPv6 parses an IPv6 address String into an Integer
	def Util.parse_IPv6(ip)
	# check that only valid characters are present
		if (ip =~ /[^0-9a-fA-F\:.]/)
			raise ValidationError, "#{ip} contains invalid characters."
		end
		
		ip = ip.strip
		if (ip == "::")
			return 0 # zero address
		end
		ipv4Int = nil
		if (ip.include?(".")) # check for ipv4 embedded addresses
			words = ip.split(":")
			begin
				ipv4Int = Util.parse_IPv4(words.last)
			rescue
				raise ValidationError, "IPv4-embedded IPv6 address is invalid."
			end
			ip = ip.sub(words.last,"0:0") # temporarily remove the ipv4 portion
		end
		words = []
		if (ip.include?("::")) # short format
			if (ip =~ /:{3,}/) # make sure only i dont have ":::"
				raise ValidationError, "#{ip} contains invalid field separator."
			end
			if (ip.scan(/::/).length != 1)
				raise ValidationError, "#{ip} contains multiple '::' sequences."
			end
			
			halves = ip.split("::")
			if (halves[0] == nil) # cases such as ::1
				halves[0] = "0"
			end
			if (halves[1] == nil) # cases such as 1::
				halves[1] = "0"
			end
			upHalf = halves[0].split(":")
			loHalf = halves[1].split(":")
			numWords = upHalf.length + loHalf.length
			if (numWords > 8)
				raise ValidationError, "#{ip} is too long."
			end
			words = upHalf
			(8-numWords).downto(1) do |i|
				words.push("0")
			end
			words.concat(loHalf)
		else
			words = ip.split(":")
			if (words.length > 8)
			   raise ValidationError, "#{ip} is too long."
			elsif (words.length < 8)
				raise ValidationError, "#{ip} is too short."
			end
		end
		ipInt = 0
		i = 8
		words.each do |word|
			i -= 1
			word = word.to_i(16) << (16*i)
			ipInt = ipInt | word
		end
		if ipv4Int # re-add ipv4 portion if present
			ipInt = ipInt | ipv4Int
		end
		return ipInt
	end
		
	# quick_sort will return a sorted copy of the provided Array.
	# The array must contain only objects which implement a cmp method and which are comparable to each other.
	def Util.quick_sort(list)
		if (list.length <= 1)
			return [].concat(list)
		end
		
		final_list = []
		lt_list = []
		gt_list = []
		eq_list = []
		pivot = list[list.length-1]
		list.each do |ip|
			cmp = pivot.cmp(ip)
			if (cmp == 1)
				lt_list.push(ip)
			elsif (cmp == -1)
				gt_list.push(ip)
			else
				eq_list.push(ip)
			end
		end
		final_list.concat( quick_sort(lt_list) )
		final_list.concat(eq_list)
		final_list.concat( quick_sort(gt_list) )
		return final_list
	end
	
	# summ_peers returns a copy of the list with any merge-able subnets summ'd together.
	def Util.summ_peers(list)
		summd = quick_sort(list)
		while true do
			list_len = summd.length
			last = list_len - 1
			tmp_list = []
			i = 0
			while (i < list_len) do
				net = summd[i]
				next_net = i+1
				if (i != last)
					# if this net and next_net summarize then discard them & keep summary
					new_net = net.summ(summd[next_net])
					if (new_net) # can summ. keep summary
						tmp_list.push(new_net)
						i += 1 # skip next_net
					else # cant summ. keep existing
						tmp_list.push(net)
					end
				else
					tmp_list.push(net) # keep last
				end
				i += 1
			end
			
			# stop when list stops getting shorter
			if (tmp_list.length == list_len)
				break
			end
			summd = tmp_list
		end
		return summd
	end
	
	end # end class
end # end module
