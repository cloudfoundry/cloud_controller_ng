module VCAP::CloudController
  class Constants
    API_VERSION = File.read(File.expand_path('../../config/version_v2', File.dirname(__FILE__))).strip.freeze
    API_VERSION_V3 = File.read(File.expand_path('../../config/version', File.dirname(__FILE__))).strip.freeze
  end
end
