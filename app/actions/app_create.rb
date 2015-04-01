module VCAP::CloudController
  class AppCreate
    class InvalidApp < StandardError; end

    def create(message)
      AppModel.create(name: message.name, space_guid: message.space_guid, environment_variables: message.environment_variables)

    rescue Sequel::ValidationFailed => e
      raise InvalidApp.new(e.message)
    end
  end
end
