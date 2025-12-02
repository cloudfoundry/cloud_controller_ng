require_relative "eui48.rb"
require_relative "eui64.rb"
require_relative "ipv4.rb"
require_relative "ipv4net.rb"
require_relative "ipv6.rb"
require_relative "ipv6net.rb"
require_relative "mask32.rb"
require_relative "mask128.rb"
require_relative "util.rb"

module NetAddr
	# Constants
	
	# 32 bits worth of '1'
	F32 = 2**32-1
	
	# 128 bits worth of '1'
	F128 = 2**128-1
	

	# ValidationError is thrown when a method fails a validation test.
  class ValidationError < StandardError
  end
	
	# ipv4_prefix_len returns the prefix length needed to hold the number of IP addresses specified by "size".
	def ipv4_prefix_len(size)
		prefix_len = 32
		32.downto(0) do |i|
			hostbits = 32 - prefix_len
			max = 1 << hostbits
			if (size <= max)
				break
			end
			prefix_len -= 1
		end
		return prefix_len
	end
	module_function :ipv4_prefix_len
	
	## parse_ip parses a string into an IPv4 or IPv6
	def parse_ip(ip)
		if (ip.include?(":"))
			return IPv6.parse(ip)
		end
		return IPv4.parse(ip)
	end
	module_function :parse_ip
	
	## parse_net parses a string into an IPv4Net or IPv6Net
	def parse_net(net)
		if (net.include?(":"))
			return IPv6Net.parse(net)
		end
		return IPv4Net.parse(net)
	end
	module_function :parse_net
	
	# sort_IPv4 sorts a list of IPv4 objects in ascending order.
	# It will return a new list with any non IPv4 objects removed.
	def sort_IPv4(list)
		if ( !list.kind_of?(Array) )
			raise ArgumentError, "Expected an Array for 'list' but got a #{list.class}."
		end
		filtered = Util.filter_IPv4(list)
		return Util.quick_sort(filtered)
	end
	module_function :sort_IPv4
	
	# sort_IPv6 sorts a list of IPv6 objects in ascending order.
	# It will return a new list with any non IPv6 objects removed.
	def sort_IPv6(list)
		if ( !list.kind_of?(Array) )
			raise ArgumentError, "Expected an Array for 'list' but got a #{list.class}."
		end
		filtered = Util.filter_IPv6(list)
		return Util.quick_sort(filtered)
	end
	module_function :sort_IPv6
	
	# sort_IPv4Net sorts a list of IPv4Net objects in ascending order.
	# It will return a new list with any non IPv4Net objects removed.
	def sort_IPv4Net(list)
		if ( !list.kind_of?(Array) )
			raise ArgumentError, "Expected an Array for 'list' but got a #{list.class}."
		end
		filtered = Util.filter_IPv4Net(list)
		return Util.quick_sort(filtered)
	end
	module_function :sort_IPv4Net
	
	# sort_IPv6Net sorts a list of IPv6Net objects in ascending order.
	# It will return a new list with any non IPv6Net objects removed.
	def sort_IPv6Net(list)
		if ( !list.kind_of?(Array) )
			raise ArgumentError, "Expected an Array for 'list' but got a #{list.class}."
		end
		filtered = Util.filter_IPv6Net(list)
		return Util.quick_sort(filtered)
	end
	module_function :sort_IPv6Net
	
	# summ_IPv4Net summarizes a list of IPv4Net objects as much as possible.
	# It will return a new list with any non IPv4Net objects removed.
	def summ_IPv4Net(list)
		list = Util.filter_IPv4Net(list)
		if (list.length>1)
			list = Util.discard_subnets(list)
			return Util.summ_peers(list)
		end
		return [].concat(list)
	end
	module_function :summ_IPv4Net
	
	# summ_IPv6Net summarizes a list of IPv6Net objects as much as possible.
	# It will return a new list with any non IPv6Net objects removed.
	def summ_IPv6Net(list)
		list = Util.filter_IPv6Net(list)
		if (list.length>1)
			list = Util.discard_subnets(list)
			return Util.summ_peers(list)
		end
		return [].concat(list)
	end
	module_function :summ_IPv6Net
	
end # end module
