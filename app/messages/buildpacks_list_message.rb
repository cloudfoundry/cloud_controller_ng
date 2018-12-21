require 'messages/list_message'

module VCAP::CloudController
  class BuildpacksListMessage < ListMessage
    register_allowed_keys [
      :page,
      :per_page,
    ]

    validates_with NoAdditionalParamsValidator

    def self.from_params(params)
      super(params, %w())
    end
  end
end
