require 'messages/list_message'

module VCAP::CloudController
  class RouteMappingsListMessage < ListMessage
    register_allowed_keys [
      :app_guid,
      :app_guids,
      :route_guids,
    ]

    validates_with NoAdditionalParamsValidator

    def to_param_hash
      super(exclude: [:app_guid])
    end

    def self.from_params(params)
      super(params, %w(app_guids route_guids))
    end
  end
end
