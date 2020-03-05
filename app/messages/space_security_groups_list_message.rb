require 'messages/list_message'

module VCAP::CloudController
  class SpaceSecurityGroupsListMessage < ListMessage
    register_allowed_keys [:names, :guids]
    validates_with NoAdditionalParamsValidator

    validates :names, allow_nil: true, array: true
    validates :guids, allow_nil: true, array: true

    def self.from_params(params)
      super(params, %w(names guids))
    end
  end
end
