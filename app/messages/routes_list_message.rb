require 'messages/metadata_list_message'

module VCAP::CloudController
  class RoutesListMessage < ListMessage
    def self.from_params(params)
      super(params, [])
    end
  end
end
