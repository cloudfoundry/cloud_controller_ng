#!/usr/bin/ruby

require_relative "../lib/netaddr.rb"
require 'test/unit'

class TestMask32 < Test::Unit::TestCase
	def test_new
		m32 = NetAddr::Mask32.new(24)
		assert_equal("/24", m32.to_s)
		assert_equal(0xffffff00, m32.mask)
		
		assert_raise(NetAddr::ValidationError){ NetAddr::Mask32.new(-1) }
		assert_raise(NetAddr::ValidationError){ NetAddr::Mask32.new(33) }
		assert_raise(NetAddr::ValidationError){ NetAddr::Mask32.new("/24") }
	end
	
	def test_parse
		m32 = NetAddr::Mask32.parse("255.255.255.0")
		assert_equal("/24", m32.to_s)
		
		m32 = NetAddr::Mask32.parse("/24")
		assert_equal("/24", m32.to_s)
		
		assert_raise(NetAddr::ValidationError){ NetAddr::Mask32.parse("255.248.255.0") }
	end
	
	def test_cmp
		m = NetAddr::Mask32.new(24)
		m2 = NetAddr::Mask32.new(25)
		m3 = NetAddr::Mask32.new(23)
		m4 = NetAddr::Mask32.new(24)
		assert_equal(1, m.cmp(m2))
		assert_equal(-1, m.cmp(m3))
		assert_equal(0, m.cmp(m4))
	end
	
	def test_extended
		m32 = NetAddr::Mask32.new(24)
		assert_equal("255.255.255.0", m32.extended)
	end
	
	def test_len
		m = NetAddr::Mask32.new(24)
		assert_equal(256, m.len())
		
		m = NetAddr::Mask32.new(26)
		assert_equal(64, m.len())
		
		m = NetAddr::Mask32.new(32)
		assert_equal(1, m.len())
		
		m = NetAddr::Mask32.new(0)
		assert_equal(0, m.len())
	end

end
