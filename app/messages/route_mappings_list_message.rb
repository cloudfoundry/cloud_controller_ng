require 'messages/list_message'

module VCAP::CloudController
  class RouteMappingsListMessage < ListMessage
    register_allowed_keys [:app_guid, :app_guids, :order_by, :page, :per_page, :route_guids]

    validates_with NoAdditionalParamsValidator

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
  end
end
