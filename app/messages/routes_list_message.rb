require 'messages/list_message'

module VCAP::CloudController
  class RoutesListMessage < ListMessage
    register_allowed_keys [
      :hosts,
      :organization_guids,
      :domain_guids,
      :paths
    ]

    validates_with NoAdditionalParamsValidator

    validates :hosts, allow_nil: true, array: true
    validates :paths, allow_nil: true, array: true
    validates :organization_guids, allow_nil: true, array: true
    validates :domain_guids, allow_nil: true, array: true

    def self.from_params(params)
      super(params, %w(hosts organization_guids domain_guids paths))
    end
  end
end
