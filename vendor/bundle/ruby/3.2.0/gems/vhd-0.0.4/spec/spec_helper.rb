Bundler.require(:test)

require File.expand_path("../../lib/vhd", __FILE__)
require 'fileutils'

RSpec.configure do |config|
  config.order = :random
end
