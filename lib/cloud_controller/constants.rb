module VCAP::CloudController
  class Constants
    API_VERSION = '2.65.0'.freeze
    API_VERSION_V3 = File.read(File.expand_path('../../config/version', File.dirname(__FILE__))).strip.freeze
  end
end
