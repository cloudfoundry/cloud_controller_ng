#!/usr/bin/ruby

require_relative "../lib/netaddr.rb"
require 'test/unit'

class TestEUI48 < Test::Unit::TestCase
	def test_new
		eui = NetAddr::EUI48.new(0)
		assert_equal("00-00-00-00-00-00", eui.to_s)
		
		assert_raise(NetAddr::ValidationError){ NetAddr::EUI48.new(2**48) }
		assert_raise(NetAddr::ValidationError){ NetAddr::EUI48.new(-1) }
		assert_raise(NetAddr::ValidationError){ NetAddr::EUI48.new("00-00-00-00-00-00") } # string
	end
	
	def test_parse
		assert_equal("aa-bb-cc-dd-ee-ff", NetAddr::EUI48.parse("aa-bb-cc-dd-ee-ff").to_s)
		assert_equal("aa-bb-cc-dd-ee-ff", NetAddr::EUI48.parse("aa:bb:cc:dd:ee:ff").to_s)
		assert_equal("aa-bb-cc-dd-ee-ff", NetAddr::EUI48.parse("aabb.ccdd.eeff").to_s)
		assert_equal("aa-bb-cc-dd-ee-ff", NetAddr::EUI48.parse("aabbccddeeff").to_s)
		
		assert_raise(NetAddr::ValidationError){ NetAddr::EUI48.parse("aa-bb-cc-dd-ee-ff-00-11") }
		assert_raise(NetAddr::ValidationError){ NetAddr::EUI48.parse("aa-bb-cc-dd-ee-gg") }
		assert_raise(NetAddr::ValidationError){ NetAddr::EUI48.parse("aa;bb;cc;dd;ee;ff") }
	end
	
	def test_to_eui64
		assert_equal("aa-bb-cc-ff-fe-dd-ee-ff", NetAddr::EUI48.parse("aa-bb-cc-dd-ee-ff").to_eui64.to_s)
	end
end
