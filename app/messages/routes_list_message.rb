require 'messages/list_message'

module VCAP::CloudController
  class RoutesListMessage < ListMessage
    register_allowed_keys [
      :hosts,
      :space_guids,
      :organization_guids,
      :domain_guids,
      :paths,
      :app_guids,
      :include,
      :label_selector,
      :ports,
      :service_instance_guids,
    ]

    validates_with NoAdditionalParamsValidator
    validates_with IncludeParamValidator, valid_values: ['domain', 'space', 'space.organization']

    validates :hosts, allow_nil: true, array: true
    validates :paths, allow_nil: true, array: true
    validates :app_guids, allow_nil: true, array: true
    validates :space_guids, allow_nil: true, array: true
    validates :organization_guids, allow_nil: true, array: true
    validates :domain_guids, allow_nil: true, array: true
    validates :ports, allow_nil: true, array: true
    validates :service_instance_guids, allow_nil: true, array: true

    def self.from_params(params)
      super(params, %w(hosts space_guids organization_guids domain_guids app_guids paths ports include service_instance_guids))
    end
  end
end
