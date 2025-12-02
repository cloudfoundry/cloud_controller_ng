#!/usr/bin/ruby

require_relative "../lib/netaddr.rb"
require 'test/unit'

class TestIPv4Net < Test::Unit::TestCase
	def test_new
		ip = NetAddr::IPv4.parse("128.0.0.1")
		m32 = NetAddr::Mask32.new(24)
		net = NetAddr::IPv4Net.new(ip,m32)
		assert_equal("128.0.0.0/24", net.to_s)

		net = NetAddr::IPv4Net.new(ip,nil)
		assert_equal("128.0.0.1/32", net.to_s)
	end
	
	def test_parse
		assert_equal("128.0.0.0/24", NetAddr::IPv4Net.parse("128.0.0.1/24").to_s)
		assert_equal("128.0.0.0/24", NetAddr::IPv4Net.parse("128.0.0.1 255.255.255.0").to_s)
		assert_equal("0.0.0.0/0", NetAddr::IPv4Net.parse("0.0.0.0/0").to_s)
		assert_equal("128.0.0.1/32", NetAddr::IPv4Net.parse("128.0.0.1").to_s) # default /32
	end
	
	def test_cmp
		net1 = NetAddr::IPv4Net.parse("1.1.1.0/24")
		net2 = NetAddr::IPv4Net.parse("1.1.0.0/24")
		net3 =NetAddr::IPv4Net.parse("1.1.2.0/24")
		net4 = NetAddr::IPv4Net.parse("1.1.1.0/25")
		net5 = NetAddr::IPv4Net.parse("1.1.1.0/24")
		
		assert_equal(1, net1.cmp(net2)) # ip less
		assert_equal(-1, net1.cmp(net3))# ip greater
		assert_equal(-1, net4.cmp(net1)) # ip eq, mask less
		assert_equal(1, net1.cmp(net4)) # ip eq, mask greater
		assert_equal(0, net1.cmp(net5)) # eq
	end
	
	def test_contains
		net = NetAddr::IPv4Net.parse("1.0.0.8/29")
		ip1 = NetAddr::IPv4.parse("1.0.0.15")
		ip2 = NetAddr::IPv4.parse("1.0.0.16")
		ip3 = NetAddr::IPv4.parse("1.0.0.7")
		
		assert_equal(true, net.contains(ip1))
		assert_equal(false, net.contains(ip2))
		assert_equal(false, net.contains(ip3))
	end
	
	def test_extended
		net = NetAddr::IPv4Net.parse("128.0.0.1/24")
		assert_equal("128.0.0.0 255.255.255.0", net.extended)
	end

	def test_fill
		# filter supernet. remove subnets of subnets. basic fwd fill.
		parent = NetAddr::IPv4Net.parse("10.0.0.0/24")
		nets = []
		["10.0.0.0/24", "10.0.0.0/8", "10.0.0.8/30", "10.0.0.16/30", "10.0.0.16/28"].each do |net|
			nets.push(NetAddr::IPv4Net.parse(net))
		end
		expect = ["10.0.0.0/29", "10.0.0.8/30", "10.0.0.12/30", "10.0.0.16/28", "10.0.0.32/27", "10.0.0.64/26", "10.0.0.128/25"]
		i = 0
		parent.fill(nets).each do |net|
			assert_equal(expect[i],net.to_s)
			i += 1
		end
		
		# basic backfill
		parent = NetAddr::IPv4Net.parse("128.0.0.0/1")
		nets = []
		["192.0.0.0/2"].each do |net|
			nets.push(NetAddr::IPv4Net.parse(net))
		end
		expect = ["128.0.0.0/2", "192.0.0.0/2"]
		i = 0
		parent.fill(nets).each do |net|
			assert_equal(expect[i],net.to_s)
			i += 1
		end
		
		# basic fwd fill with non-contiguous subnets
		parent = NetAddr::IPv4Net.parse("1.0.0.0/25")
		nets = []
		["1.0.0.0/30", "1.0.0.64/26"].each do |net|
			nets.push(NetAddr::IPv4Net.parse(net))
		end
		expect = ["1.0.0.0/30", "1.0.0.4/30", "1.0.0.8/29", "1.0.0.16/28", "1.0.0.32/27", "1.0.0.64/26"]
		i = 0
		parent.fill(nets).each do |net|
			assert_equal(expect[i],net.to_s)
			i += 1
		end
    
		# basic backfill. complex fwd fill that uses 'shrink' of the proposed 1.0.16.0/21 subnet
    parent = NetAddr::IPv4Net.parse("1.0.0.0/19")
		nets = []
		["1.0.8.0/21", "1.0.20.0/24"].each do |net|
			nets.push(NetAddr::IPv4Net.parse(net))
		end
		expect = ["1.0.0.0/21","1.0.8.0/21","1.0.16.0/22","1.0.20.0/24","1.0.21.0/24","1.0.22.0/23","1.0.24.0/21"]
		i = 0
		parent.fill(nets).each do |net|
			assert_equal(expect[i],net.to_s)
			i += 1
		end
		
		# list contains the supernet
		parent = NetAddr::IPv4Net.parse("1.0.0.0/19")
		nets = []
		["1.0.0.0/19"].each do |net|
			nets.push(NetAddr::IPv4Net.parse(net))
		end
		expect = []
		i = 0
		parent.fill(nets).each do |net|
			assert_equal(expect[i],net.to_s)
			i += 1
		end
	end
	
	def test_len
		net1 = NetAddr::IPv4Net.parse("1.1.1.0/24")
		assert_equal(256, net1.len())
	end
	
	def test_next
		assert_equal("1.0.0.2/31", NetAddr::IPv4Net.parse("1.0.0.0/31").next.to_s)
		assert_equal("1.0.0.8/29", NetAddr::IPv4Net.parse("1.0.0.4/30").next.to_s)
		assert_equal("1.0.0.16/28", NetAddr::IPv4Net.parse("1.0.0.8/29").next.to_s)
	end
	
	def test_next_sib
		assert_equal("255.255.255.64/26", NetAddr::IPv4Net.parse("255.255.255.0/26").next_sib.to_s)
		assert_equal("255.255.255.128/26", NetAddr::IPv4Net.parse("255.255.255.64/26").next_sib.to_s)
		assert_equal("255.255.255.192/26", NetAddr::IPv4Net.parse("255.255.255.128/26").next_sib.to_s)
		assert_nil(NetAddr::IPv4Net.parse("255.255.255.192/26").next_sib)
	end
	
	def test_nth
		assert_equal("1.1.1.1", NetAddr::IPv4Net.parse("1.1.1.0/26").nth(1).to_s)
		assert_nil(NetAddr::IPv4Net.parse("1.1.1.0/26").nth(64))
	end
	
	def test_nth_subnet
		assert_equal("1.1.1.0/26", NetAddr::IPv4Net.parse("1.1.1.0/24").nth_subnet(26,0).to_s)
		assert_equal("1.1.1.64/26", NetAddr::IPv4Net.parse("1.1.1.0/24").nth_subnet(26,1).to_s)
		assert_nil(NetAddr::IPv4Net.parse("1.1.1.0/24").nth_subnet(26,4))
		assert_nil(NetAddr::IPv4Net.parse("1.1.1.0/24").nth_subnet(26,-1))
		assert_nil(NetAddr::IPv4Net.parse("1.1.1.0/24").nth_subnet(24,0))
	end
	
	def test_prev
		assert_equal("1.0.0.0/29", NetAddr::IPv4Net.parse("1.0.0.8/30").prev.to_s)
		assert_equal("1.0.0.128/26", NetAddr::IPv4Net.parse("1.0.0.192/26").prev.to_s)
		assert_equal("1.0.0.0/25", NetAddr::IPv4Net.parse("1.0.0.128/26").prev.to_s)
	end
	
	def test_prev_sib
		assert_equal("0.0.0.64/26", NetAddr::IPv4Net.parse("0.0.0.128/26").prev_sib.to_s)
		assert_equal("0.0.0.0/26", NetAddr::IPv4Net.parse("0.0.0.64/26").prev_sib.to_s)
		assert_nil(NetAddr::IPv4Net.parse("0.0.0.0/26").prev_sib)
	end
	
	def test_rel
		net1 = NetAddr::IPv4Net.parse("1.1.1.0/24")
		net2 = NetAddr::IPv4Net.parse("1.1.1.0/25")
		net3 = NetAddr::IPv4Net.parse("1.1.1.128/25")
		net4 = NetAddr::IPv4Net.parse("1.1.1.0/25")
		assert_equal(1, net1.rel(net2)) # net eq, supernet
		assert_equal(-1, net2.rel(net1)) # net eq, subnet
		assert_equal(0, net2.rel(net2)) # eq
		assert_equal(1, net1.rel(net3)) # net ne, supernet
		assert_equal(-1, net3.rel(net1)) # net ne, subnet
		assert_nil(net3.rel(net4)) # unrelated
	end
	
	def test_resize
		assert_equal("1.1.1.0/24", NetAddr::IPv4Net.parse("1.1.1.0/26").resize(24).to_s)
	end
	
	def test_subnet_count
		assert_equal(2, NetAddr::IPv4Net.parse("1.1.1.0/24").subnet_count(25))
		assert_equal(0, NetAddr::IPv4Net.parse("1.1.1.0/24").subnet_count(24))
		assert_equal(0, NetAddr::IPv4Net.parse("1.1.1.0/24").subnet_count(33))
		assert_equal(0, NetAddr::IPv4Net.parse("0.0.0.0/0").subnet_count(32))
	end
	
	def test_summ
		net1 = NetAddr::IPv4Net.parse("1.1.1.0/30")
		net2 = NetAddr::IPv4Net.parse("1.1.1.4/30")
		net3 = NetAddr::IPv4Net.parse("1.1.1.16/28")
		net4 = NetAddr::IPv4Net.parse("1.1.1.0/28")
		net5 = NetAddr::IPv4Net.parse("1.1.2.0/30")
		net6 = NetAddr::IPv4Net.parse("1.1.1.4/30")
		net7 = NetAddr::IPv4Net.parse("1.1.1.16/28")
		net8 = NetAddr::IPv4Net.parse("1.1.1.32/28")
		net9 = NetAddr::IPv4Net.parse("1.1.1.0/29")
		net10 = NetAddr::IPv4Net.parse("1.1.1.8/30")
		assert_equal("1.1.1.0/29", net1.summ(net2).to_s) # lesser to greater
		assert_equal("1.1.1.0/27", net3.summ(net4).to_s) # greater to lesser
		assert_nil(net5.summ(net6)) # different nets
		assert_nil(net7.summ(net8)) # consecutive but not within bit boundary
		assert_nil(net9.summ(net10)) # within bit boundary, but not same size
	end
	
end
