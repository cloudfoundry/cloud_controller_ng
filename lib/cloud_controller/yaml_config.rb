require 'yaml'

module VCAP::CloudController
  class YAMLConfig
    class << self
      def safe_load_file(filepath)
        File.open(filepath) do |f|
          YAML.safe_load(f)
        end
      end
    end
  end
end
