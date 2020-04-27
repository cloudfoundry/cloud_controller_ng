require 'messages/list_message'

module VCAP::CloudController
  class RoutesListMessage < ListMessage
    register_allowed_keys [
      :hosts,
      :app_guids,
      :space_guids,
      :organization_guids,
      :domain_guids,
      :paths,
      :include,
      :label_selector,
    ]

    validates_with NoAdditionalParamsValidator
    validates_with IncludeParamValidator, valid_values: ['domain']

    validates :hosts, allow_nil: true, array: true
    validates :paths, allow_nil: true, array: true
    validates :app_guids, allow_nil: true, array: true
    validates :space_guids, allow_nil: true, array: true
    validates :organization_guids, allow_nil: true, array: true
    validates :domain_guids, allow_nil: true, array: true

    def self.from_params(params)
      super(params, %w(hosts app_guids space_guids organization_guids domain_guids paths include))
    end
  end
end
