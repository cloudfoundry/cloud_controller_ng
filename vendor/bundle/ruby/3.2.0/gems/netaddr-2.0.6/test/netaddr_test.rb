#!/usr/bin/ruby

require_relative "../lib/netaddr.rb"
require 'test/unit'

class TestNetAddr < Test::Unit::TestCase

	def test_parse_ip
		assert_equal("128.0.0.1", NetAddr.parse_ip("128.0.0.1").to_s)
		assert_equal("1::1", NetAddr.parse_ip("1::1").to_s)
	end
	
	def test_parse_net
		assert_equal("128.0.0.1/32", NetAddr.parse_net("128.0.0.1/32").to_s)
		assert_equal("1::/24", NetAddr.parse_net("1::1/24").to_s)
		assert_equal("::ffff:aabb:ccdd/128", NetAddr.parse_net("::ffff:170.187.204.221/128").to_s)
	end
	
	def test_ipv4_prefix_len
		assert_equal(32,NetAddr.ipv4_prefix_len(1))
		assert_equal(27,NetAddr.ipv4_prefix_len(30))
		assert_equal(24,NetAddr.ipv4_prefix_len(254))
		assert_equal(16,NetAddr.ipv4_prefix_len(0xfffe))
		assert_equal(8,NetAddr.ipv4_prefix_len(0xfffffe))
		assert_equal(0,NetAddr.ipv4_prefix_len(0xffffffff))
	end
	
	def test_sort_IPv4
		ips = []
		["10.0.0.0","1.1.1.1","0.0.0.0","10.1.10.1"].each do |net|
			ips.push(NetAddr::IPv4.parse(net))
		end
		sorted = NetAddr.sort_IPv4(ips)
		expect = [ips[2],ips[1],ips[0],ips[3]]
		assert_equal(expect, sorted)
	end
	
	def test_sort_IPv4Net
		nets = []
		["10.0.0.0/24", "1.0.0.0/24", "10.0.0.0/8", "192.168.1.0/26", "8.8.8.8/32"].each do |net|
			nets.push(NetAddr::IPv4Net.parse(net))
		end
		sorted = NetAddr.sort_IPv4Net(nets)
		expect = [nets[1],nets[4],nets[0],nets[2],nets[3]]
		assert_equal(expect, sorted)
	end
	
	def test_summ_IPv4Net
		nets = []
		["10.0.0.0/29", "10.0.0.8/30", "10.0.0.12/30", "10.0.0.16/28", "10.0.0.32/27", "10.0.0.64/26", "10.0.0.128/25"].each do |net|
			nets.push(NetAddr::IPv4Net.parse(net))
		end
		expect = ["10.0.0.0/24"]
		i = 0
		NetAddr.summ_IPv4Net(nets).each do |net|
			assert_equal(expect[i],net.to_s)
			i += 1
		end
		
		nets = []
		["10.0.0.0/24", "1.0.0.0/8", "3.4.5.6/32", "3.4.5.8/31", "0.0.0.0/0"].each do |net|
			nets.push(NetAddr::IPv4Net.parse(net))
		end
		expect = ["0.0.0.0/0"]
		i = 0
		NetAddr.summ_IPv4Net(nets).each do |net|
			assert_equal(expect[i],net.to_s)
			i += 1
		end
		
		nets = []
		["10.0.1.0/25", "10.0.1.0/26", "10.0.0.16/28", "10.0.0.32/27", "10.0.0.128/26", "10.0.0.192/26", "10.0.0.32/27"].each do |net|
			nets.push(NetAddr::IPv4Net.parse(net))
		end
		expect = ["10.0.0.16/28", "10.0.0.32/27", "10.0.0.128/25", "10.0.1.0/25"]
		i = 0
		NetAddr.summ_IPv4Net(nets).each do |net|
			assert_equal(expect[i],net.to_s)
			i += 1
		end
		
		nets = []
		["10.0.0.0/26","10.0.0.64/26","10.0.0.0/24","10.0.0.192/26","10.0.0.128/26"].each do |net| # test out of order
			nets.push(NetAddr::IPv4Net.parse(net))
		end
		expect = ["10.0.0.0/24"]
		i = 0
		NetAddr.summ_IPv4Net(nets).each do |net|
			assert_equal(expect[i],net.to_s)
			i += 1
		end
	end
	
	def test_sort_IPv6
		ips = []
		["1::", "3::", "2::", "::", "::1"].each do |net|
			ips.push(NetAddr::IPv6.parse(net))
		end
		sorted = NetAddr.sort_IPv6(ips)
		expect = [ips[3],ips[4],ips[0],ips[2],ips[1]]
		assert_equal(expect, sorted)
	end
	
	def test_sort_IPv6Net
		nets = []
		["1::/64", "2::/64", "1::/16", "::", "::1"].each do |net|
			nets.push(NetAddr::IPv6Net.parse(net))
		end
		sorted = NetAddr.sort_IPv6Net(nets)
		expect = [nets[3],nets[4],nets[0],nets[2],nets[1]] # ::/128 ::1/128 1::/64 1::/16 2::/64
		assert_equal(expect, sorted)
	end
	
	def test_summ_IPv6Net
		nets = []
		["ff00::/13", "ff08::/14", "ff0c::/14", "ff10::/12", "ff20::/11", "ff40::/10", "ff80::/9"].each do |net|
			nets.push(NetAddr::IPv6Net.parse(net))
		end
		expect = ["ff00::/8"]
		i = 0
		NetAddr.summ_IPv6Net(nets).each do |net|
			assert_equal(expect[i],net.to_s)
			i += 1
		end
		
		nets = []
		["2::/32", "::1", "fec0::/16", "1::/16", "::/0"].each do |net|
			nets.push(NetAddr::IPv6Net.parse(net))
		end
		expect = ["::/0"]
		i = 0
		NetAddr.summ_IPv6Net(nets).each do |net|
			assert_equal(expect[i],net.to_s)
			i += 1
		end
		
		nets = []
		["ff80::/9", "ff10::/12", "ff80::/10", "ff20::/12", "fff0::/16", "fff1::/16", "ff80::/10"].each do |net|
			nets.push(NetAddr::IPv6Net.parse(net))
		end
		expect = ["ff10::/12", "ff20::/12", "ff80::/9", "fff0::/15"]
		i = 0
		NetAddr.summ_IPv6Net(nets).each do |net|
			assert_equal(expect[i],net.to_s)
			i += 1
		end
	end

end
