require 'messages/list_message'

module VCAP::CloudController
  class RouteMappingsListMessage < ListMessage
    ALLOWED_KEYS = [:app_guid, :app_guids, :order_by, :page, :per_page, :route_guids].freeze

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalParamsValidator

    def initialize(params={})
      super(params.symbolize_keys)
    end

    def to_param_hash
      super(exclude: [:app_guid])
    end

    def self.from_params(params)
      opts = params.dup

      ['app_guids', 'route_guids'].each do |key|
        to_array!(opts, key)
      end

      new(opts.symbolize_keys)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
