require 'messages/list_message'

module VCAP::CloudController
  class ServiceBindingsListMessage < ListMessage
    ALLOWED_KEYS = [:app_guids, :service_instance_guids, :order_by, :page, :per_page].freeze

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalParamsValidator

    def self.from_params(params)
      opts = params.dup

      %w(app_guids service_instance_guids).each do |key|
        to_array!(opts, key)
      end

      new(opts.symbolize_keys)
    end

    def initialize(params={})
      super(params.symbolize_keys)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
