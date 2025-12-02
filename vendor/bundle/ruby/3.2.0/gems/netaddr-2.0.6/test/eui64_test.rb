#!/usr/bin/ruby

require_relative "../lib/netaddr.rb"
require 'test/unit'

class TestEUI64 < Test::Unit::TestCase
	def test_new
		eui = NetAddr::EUI64.new(0)
		assert_equal("00-00-00-00-00-00-00-00", eui.to_s)
		
		assert_raise(NetAddr::ValidationError){ NetAddr::EUI64.new(2**64) }
		assert_raise(NetAddr::ValidationError){ NetAddr::EUI64.new(-1) }
		assert_raise(NetAddr::ValidationError){ NetAddr::EUI64.new("00-00-00-00-00-00-00-00") } # string
	end
	
	def test_parse
		assert_equal("aa-bb-cc-dd-ee-ff-00-11", NetAddr::EUI64.parse("aa-bb-cc-dd-ee-ff-00-11").to_s)
		assert_equal("aa-bb-cc-dd-ee-ff-00-11", NetAddr::EUI64.parse("aa:bb:cc:dd:ee:ff:00:11").to_s)
		assert_equal("aa-bb-cc-dd-ee-ff-00-11", NetAddr::EUI64.parse("aabb.ccdd.eeff.0011").to_s)
		assert_equal("aa-bb-cc-dd-ee-ff-00-11", NetAddr::EUI64.parse("aabbccddeeff0011").to_s)
		
		assert_raise(NetAddr::ValidationError){ NetAddr::EUI64.parse("aa-bb-cc-dd-ee-ff-00-11-22") }
		assert_raise(NetAddr::ValidationError){ NetAddr::EUI64.parse("aa-bb-cc-dd-ee-ff-gg") }
		assert_raise(NetAddr::ValidationError){ NetAddr::EUI64.parse("aa;bb;cc;dd;ee;ff;00;11") }
	end
	
	def test_to_ipv6
		net = NetAddr::IPv6Net.parse("fe80::/64")
		eui = NetAddr::EUI64.parse("aa-bb-cc-dd-ee-ff-00-11")
		assert_equal("fe80::a8bb:ccdd:eeff:11", eui.to_ipv6(net).to_s)
	end
end
