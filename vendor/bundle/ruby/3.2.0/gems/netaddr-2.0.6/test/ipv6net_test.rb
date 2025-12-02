#!/usr/bin/ruby

require_relative "../lib/netaddr.rb"
require 'test/unit'

class TestIPv6Net < Test::Unit::TestCase
	def test_new
		ip = NetAddr::IPv6.parse("1::")
		m128 = NetAddr::Mask128.new(24)
		net = NetAddr::IPv6Net.new(ip,m128)
		assert_equal("1::/24", net.to_s)

		assert_equal("1::/64", NetAddr::IPv6Net.new(ip,nil).to_s)
		
		ip = NetAddr::IPv6.parse("::")
		assert_equal("::/128", NetAddr::IPv6Net.new(ip,nil).to_s)
	end
	
	def test_parse
		assert_equal("1::/24", NetAddr::IPv6Net.parse("1::1/24").to_s)
		assert_equal("::/128", NetAddr::IPv6Net.parse("::").to_s) # default /128
		assert_equal("1::/64", NetAddr::IPv6Net.parse("1::1").to_s) # default /64
	end
	
	def test_cmp
		net1 = NetAddr::IPv6Net.parse("1:1::/32")
		net2 = NetAddr::IPv6Net.parse("1::/32")
		net3 =NetAddr::IPv6Net.parse("1:2::/32")
		net4 = NetAddr::IPv6Net.parse("1:1::/33")
		net5 = NetAddr::IPv6Net.parse("1:1::/32")
		
		assert_equal(1, net1.cmp(net2)) # ip less
		assert_equal(-1, net1.cmp(net3))# ip greater
		assert_equal(-1, net4.cmp(net1)) # ip eq, mask less
		assert_equal(1, net1.cmp(net4)) # ip eq, mask greater
		assert_equal(0, net1.cmp(net5)) # eq
	end
	
	def test_contains
		net = NetAddr::IPv6Net.parse("1:8::/29")
		ip1 = NetAddr::IPv6.parse("1:f::")
		ip2 = NetAddr::IPv6.parse("1:10::")
		ip3 = NetAddr::IPv6.parse("1:7::")
		
		assert_equal(true, net.contains(ip1))
		assert_equal(false, net.contains(ip2))
		assert_equal(false, net.contains(ip3))
	end

	def test_fill
		# filter supernet. remove subnets of subnets. basic fwd fill.
		parent = NetAddr::IPv6Net.parse("ff00::/8")
		nets = []
		["ff00::/8", "ff00::/9", "ff08::/14", "fe00::/7", "ff20::/11", "ff20::/12"].each do |net|
			nets.push(NetAddr::IPv6Net.parse(net))
		end
		expect = ["ff00::/9", "ff80::/9"]
		i = 0
		parent.fill(nets).each do |net|
			assert_equal(expect[i],net.to_s)
			i += 1
		end
		
		# basic backfill
		parent = NetAddr::IPv6Net.parse("8000::/1")
		nets = []
		["c000::/2"].each do |net|
			nets.push(NetAddr::IPv6Net.parse(net))
		end
		expect = ["8000::/2","c000::/2"]
		i = 0
		parent.fill(nets).each do |net|
			assert_equal(expect[i],net.to_s)
			i += 1
		end
		
		# basic fwd fill with non-contiguous subnets
		parent = NetAddr::IPv6Net.parse("ff00::/121")
		nets = []
		["ff00::/126", "ff00::/120"].each do |net|
			nets.push(NetAddr::IPv6Net.parse(net))
		end
		expect = ["ff00::/126", "ff00::4/126", "ff00::8/125", "ff00::10/124", "ff00::20/123", "ff00::40/122"]
		i = 0
		parent.fill(nets).each do |net|
			assert_equal(expect[i],net.to_s)
			i += 1
		end
		
		# basic backfill. complex fwd fill that uses 'shrink' of the proposed ffff:ffff:ffff:fff8::/62 subnet. designed to cross the /64 bit boundary.
		parent = NetAddr::IPv6Net.parse("fff:ffff:ffff:fff0::/60")
		nets = []
		["ffff:ffff:ffff:fff4::/62", "ffff:ffff:ffff:fffb::/65"].each do |net|
			nets.push(NetAddr::IPv6Net.parse(net))
		end
		expect = ["ffff:ffff:ffff:fff0::/62", "ffff:ffff:ffff:fff4::/62", "ffff:ffff:ffff:fff8::/63", "ffff:ffff:ffff:fffa::/64", "ffff:ffff:ffff:fffb::/65",
			"ffff:ffff:ffff:fffb:8000::/65", "ffff:ffff:ffff:fffc::/62"]
		i = 0
		parent.fill(nets).each do |net|
			assert_equal(expect[i],net.to_s)
			i += 1
		end
		
		# list contains the supernet
		parent = NetAddr::IPv6Net.parse("ffff::/16")
		nets = []
		["ffff::/16"].each do |net|
			nets.push(NetAddr::IPv6Net.parse(net))
		end
		expect = []
		i = 0
		parent.fill(nets).each do |net|
			assert_equal(expect[i],net.to_s)
			i += 1
		end
	end
	
	def test_next
		assert_equal("::2/127", NetAddr::IPv6Net.parse("::/127").next.to_s)
		assert_equal("::8/125", NetAddr::IPv6Net.parse("::4/126").next.to_s)
		assert_equal("0:0:0:2::/63", NetAddr::IPv6Net.parse("::1:8000:0:0:0/65").next.to_s)
		assert_equal("0:0:0:3::/64", NetAddr::IPv6Net.parse("::2:8000:0:0:0/65").next.to_s)
		assert_nil(NetAddr::IPv6Net.parse("ffff::/16").next)
	end
	
	def test_next_sib
		assert_equal("0:0:0:2::/65", NetAddr::IPv6Net.parse("::1:8000:0:0:0/65",).next_sib.to_s)
		assert_equal("0:0:0:2::/64", NetAddr::IPv6Net.parse("0:0:0:1::/64",).next_sib.to_s)
		assert_equal("2::/16", NetAddr::IPv6Net.parse("1::/16").next_sib.to_s)
		assert_nil(NetAddr::IPv6Net.parse("ffff::/16").next_sib)
	end
	
	def test_nth
		assert_equal("1::", NetAddr::IPv6Net.parse("1::0/64").nth(0).to_s)
		assert_equal("::", NetAddr::IPv6Net.parse("::/127").nth(0).to_s)
		assert_equal("::1", NetAddr::IPv6Net.parse("::/127").nth(1).to_s)
		assert_nil(NetAddr::IPv6Net.parse("::/127").nth(2))
	end
	
	def test_nth_subnet
		assert_equal("1::/30", NetAddr::IPv6Net.parse("1::/24").nth_subnet(30,0).to_s)
		assert_nil(NetAddr::IPv6Net.parse("1::").nth_subnet(26,4))
	end
	
	def test_prev
		assert_equal("1::/125", NetAddr::IPv6Net.parse("1::8/126").prev.to_s)
		assert_equal("f::/63", NetAddr::IPv6Net.parse("f:0:0:2::/63").prev.to_s)
		assert_equal("e::/16", NetAddr::IPv6Net.parse("f::/63").prev.to_s)
		assert_nil(NetAddr::IPv6Net.parse("::").prev)
	end
	
	def test_prev_sib
		assert_equal("0:0:0:1::/64", NetAddr::IPv6Net.parse("0:0:0:2::/64").prev_sib.to_s)
		assert_equal("1::/16", NetAddr::IPv6Net.parse("2::/16").prev_sib.to_s)
		assert_nil(NetAddr::IPv6Net.parse("::/64").prev_sib)
	end
	
	def test_rel
		net1 = NetAddr::IPv6Net.parse("1::/63")
		net2 = NetAddr::IPv6Net.parse("1::/64")
		net3 = NetAddr::IPv6Net.parse("1::/60")
		net4 = NetAddr::IPv6Net.parse("1:0:0:1::/64")
		net5 = NetAddr::IPv6Net.parse("2::/64")
		assert_equal(1, net1.rel(net2)) # net eq, supernet
		assert_equal(-1, net2.rel(net1)) # net eq, subnet
		assert_equal(0, net2.rel(net2)) # eq
		assert_equal(1, net3.rel(net4)) # net ne, supernet
		assert_equal(-1, net4.rel(net3)) # net ne, subnet
		assert_nil(net2.rel(net5)) # unrelated
	end
	
	def test_resize
		assert_equal("1::/64", NetAddr::IPv6Net.parse("1::/63").resize(64).to_s)
	end
	
	def test_subnet_count
		assert_equal(2, NetAddr::IPv6Net.parse("ff::/8").subnet_count(9))
		assert_equal(4, NetAddr::IPv6Net.parse("ff::/8").subnet_count(10))
		assert_equal(0, NetAddr::IPv6Net.parse("ff::/8").subnet_count(8))
		assert_equal(0, NetAddr::IPv6Net.parse("::/0").subnet_count(128))
	end
	
	def test_summ
		net1 = NetAddr::IPv6Net.parse("1::/128")
		net2 = NetAddr::IPv6Net.parse("1::1/128")
		net3 = NetAddr::IPv6Net.parse("1::0/128")
		net4 = NetAddr::IPv6Net.parse("1::/16")
		net5 = NetAddr::IPv6Net.parse("2::/16")
		net6 = NetAddr::IPv6Net.parse("10::/12")
		net7 = NetAddr::IPv6Net.parse("20::/12")
		net8 = NetAddr::IPv6Net.parse("8::/17")
		assert_equal("1::/127", net1.summ(net2).to_s) # lesser to greater
		assert_equal("1::/127", net2.summ(net3).to_s) # greater to lesser
		assert_nil(net4.summ(net5)) # different nets
		assert_nil(net6.summ(net7)) # consecutive but not within bit boundary
		assert_nil(net4.summ(net8)) # within bit boundary, but not same size
	end
	
end
