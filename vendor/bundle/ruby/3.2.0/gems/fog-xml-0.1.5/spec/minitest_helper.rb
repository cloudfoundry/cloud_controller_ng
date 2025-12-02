require "minitest/spec"
require "minitest/autorun"
require "excon"
require "fog/core"

if ENV["COVERAGE"]
  require "coveralls"
  require "simplecov"

  SimpleCov.start do
    add_filter "/spec/"
  end
end

require File.join(File.dirname(__FILE__), "../lib/fog/xml")

Coveralls.wear! if ENV["COVERAGE"]
