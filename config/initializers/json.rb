require 'active_support/json/encoding'

module CCInitializers
  def self.json(_cc_config)
    ActiveSupport.json_encoder = Class.new do
      attr_reader :options

      def initialize(options=nil)
        @options = options || {}
      end

      def encode(value)
        if Rails.env.test?
          MultiJson.dump(value.as_json(options.dup))
        else
          MultiJson.dump(value.as_json(options.dup), options.merge(pretty: true))
        end
      end
    end
  end
end
