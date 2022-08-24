require 'active_support/json/encoding'

module CCInitializers
  def self.json(cc_config)
    MultiJson.use(:oj)
    Oj::Rails.optimize # Use optimized encoders instead of as_json() methods for available classes.
    Oj.default_options = {
      bigdecimal_load: :bigdecimal,
      mode: :rails,
    }

    ActiveSupport.json_encoder = Class.new do
      attr_reader :options

      def initialize(options=nil)
        @options = options || {}
      end

      def encode(value)
        if MultiJson.default_adapter == :oj && value.is_a?(VCAP::CloudController::Presenters::V3::BasePresenter)
          v = value.to_hash
        else
          v = value.as_json(options.dup)
        end

        if Rails.env.test?
          Oj.dump(v, time_format: :ruby)
        else
          Oj.dump(v, options.merge(pretty: true, time_format: :ruby))
        end
      end
    end
  end
end
