require 'messages/apps_list_message'

module VCAP::CloudController
  class StackAppsListMessage < AppsListMessage
    def self.from_params(params, stack_name:)
      params['stacks'] = stack_name
      super(params)
    end
  end
end
