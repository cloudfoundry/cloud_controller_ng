#!/usr/bin/ruby

require_relative "../lib/netaddr.rb"
require 'test/unit'

# Testable examples on how to use NetAddr
class NetAddrExamples < Test::Unit::TestCase
	
	# IPv4
	def test_IPv4_examples
		puts "\n*** Examples using IPv4 ***\n"
		
		puts "\nWhat size network do I need in order to hold 200 addresses?"
		puts "/" + NetAddr.ipv4_prefix_len(200).to_s
		assert_equal(24,NetAddr.ipv4_prefix_len(200))
		
		puts "\nCreating IPv4Net: '10.0.0.0/24'"
		net = NetAddr::IPv4Net.parse("10.0.0.0/24")
		assert_not_nil(net)
		
		puts "\nRendering as a String: " + net.to_s
		assert_equal("10.0.0.0/24", net.to_s)
		
		puts "\nIterating its /26 subnets:"
		expect = ["10.0.0.0/26","10.0.0.64/26","10.0.0.128/26","10.0.0.192/26"]
		0.upto(net.subnet_count(26) - 1) do |i|
			subnet = net.nth_subnet(26,i)
			assert_equal(expect[i], subnet.to_s)
			puts "  " + subnet.to_s
		end
		
		puts "\nIts 3rd /30 subnet:"
		subnet30 = net.nth_subnet(30,2)
		assert_equal("10.0.0.8/30", subnet30.to_s)
		puts "  " + subnet30.to_s
		
		puts "\nIterating the IPs of the /30"
		expect = ["10.0.0.8","10.0.0.9","10.0.0.10","10.0.0.11"]
		0.upto(subnet30.len - 1) do |i|
			ip = subnet30.nth(i)
			assert_equal(expect[i], ip.to_s)
			puts "  " + ip.to_s
		end
		
		puts "\nDoes 10.0.0.7 belong to the 10.0.0.8/29 subnet?"
		subnet29 = NetAddr::IPv4Net.parse("10.0.0.8/29")
		if subnet29.contains(NetAddr::IPv4.parse("10.0.0.7"))
			puts " yes"
		else
			puts " no"
		end
		
		puts "\nDoes 10.0.0.10 belong to the 10.0.0.8/29 subnet?"
		if subnet29.contains(NetAddr::IPv4.parse("10.0.0.10"))
			puts " yes"
		else
			puts " no"
		end 
		
		puts "\nGiven the 3rd /30 of 10.0.0.0/24, fill in the holes:"
		expect = ["10.0.0.0/29","10.0.0.8/30","10.0.0.12/30","10.0.0.16/28","10.0.0.32/27","10.0.0.64/26","10.0.0.128/25"]
		i = 0
		net.fill([subnet30]).each do |subnet|
			puts "  " + subnet.to_s
			assert_equal(expect[i], subnet.to_s)
			i+=1
		end
		
		list = ["10.0.1.0/24", "10.0.0.0/25", "10.0.0.128/26","10.0.2.0/24", "10.0.0.192/26",]
		puts "\nSummarizing this list of networks: " + list.to_s
		nets = []
		list.each do |net|
			nets.push(NetAddr::IPv4Net.parse(net))
		end
		expect = ["10.0.0.0/23", "10.0.2.0/24",]
		i = 0
		NetAddr.summ_IPv4Net(nets).each do |net|
			puts "  " + net.to_s
			assert_equal(expect[i],net.to_s)
			i += 1
		end
		
		puts "\nThe multicast mac-address for 235.147.18.23 is:"
		mac = NetAddr::IPv4.parse("235.147.18.23").multicast_mac.to_s
		assert_equal("01-00-5e-13-12-17", mac)
		puts "  " + mac
	end
	
	# IPv6
	def test_IPv6_examples
		puts "\n\n*** Examples using IPv6 ***\n"
		
		puts "\nCreating IPv6Net: 'fec0::/62'"
		net = NetAddr::IPv6Net.parse("fec0::/62")
		assert_not_nil(net)
		
		puts "\nRendering as a String: " + net.to_s
		assert_equal("fec0::/62", net.to_s)
		
		puts "\nRendering as a String (long format): " + net.long
		assert_equal("fec0:0000:0000:0000:0000:0000:0000:0000/62", net.long)
		
		puts "\nIterating its /64 subnets:"
		expect = ["fec0::/64","fec0:0:0:1::/64","fec0:0:0:2::/64","fec0:0:0:3::/64"]
		0.upto(net.subnet_count(64) - 1) do |i|
			subnet = net.nth_subnet(64,i)
			assert_equal(expect[i], subnet.to_s)
			puts "  " + subnet.to_s
		end
		
		puts "\nIts 3rd /64 subnet:"
		subnet64 = net.nth_subnet(64,2)
		assert_equal("fec0:0:0:2::/64", subnet64.to_s)
		puts "  " + subnet64.to_s
		
		puts "\nIterating the first 4 IPs of the /64"
		expect = ["fec0:0:0:2::","fec0:0:0:2::1","fec0:0:0:2::2","fec0:0:0:2::3"]
		0.upto(3) do |i|
			ip = subnet64.nth(i)
			assert_equal(expect[i], ip.to_s)
			puts "  " + ip.to_s
		end
		
		puts "\nGiven the 3rd /64 of fec0::/62, fill in the holes:"
		expect = ["fec0::/63", "fec0:0:0:2::/64","fec0:0:0:3::/64"]
		i = 0
		net.fill([subnet64]).each do |subnet|
			puts "  " + subnet.to_s
			assert_equal(expect[i], subnet.to_s)
			i+=1
		end
		
		list = ["fec0::/63", "fec0:0:0:3::/64", "fec0:0:0:2::/64", "fe80::/17", "fe80:8000::/17"]
		puts "\nSummarizing this list of networks: " + list.to_s
		nets = []
		list.each do |net|
			nets.push(NetAddr::IPv6Net.parse(net))
		end
		expect = ["fe80::/16", "fec0::/62"]
		i = 0
		NetAddr.summ_IPv6Net(nets).each do |net|
			puts "  " + net.to_s
			assert_equal(expect[i],net.to_s)
			i += 1
		end
		
		puts "\nThe IPv6 address for mac-address aa-bb-cc-dd-ee-ff within network fe80::/64 is:"
		net = NetAddr::IPv6Net.parse("fe80::/64")
		eui = NetAddr::EUI48.parse("aa-bb-cc-dd-ee-ff").to_eui64
		ip = eui.to_ipv6(net)
		assert_equal("fe80::a8bb:ccff:fedd:eeff",ip.to_s)
		puts "  " + ip.to_s
	end
	
end
