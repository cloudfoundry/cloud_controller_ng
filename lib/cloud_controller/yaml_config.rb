require 'psych'

module VCAP::CloudController
  class YAMLConfig
    class << self
      def safe_load_file(filepath)
        File.open(filepath) do |f|
          Psych.safe_load(f, strict_integer: true)
        end
      end
    end
  end
end
