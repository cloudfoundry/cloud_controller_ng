module VCAP
  module CloudController
    module ServiceCredentialBinding
      module Types
        SERVICE_KEY = 'key'.freeze
        SERVICE_BINDING = 'app'.freeze
      end

      SERVICE_KEY_VIEW = VCAP::CloudController::ServiceKey.select(
        :guid,
        Sequel.as(Types::SERVICE_KEY, :type),
        :service_instance_id,
        Sequel.as(nil, :app_guid)
      ).freeze

      SERVICE_BINDING_VIEW = VCAP::CloudController::ServiceBinding.select(
        :guid,
        Sequel.as(Types::SERVICE_BINDING, :type),
        Sequel.as(nil, :service_instance_id),
        :app_guid
      ).freeze

      VIEW = [
        SERVICE_KEY_VIEW,
        SERVICE_BINDING_VIEW
      ].inject do |statement, sub_select|
        statement.union(sub_select, all: true, from_self: false)
      end.from_self.freeze

      class View < Sequel::Model(VIEW)
        many_to_one :service_instance, class: 'VCAP::CloudController::ServiceInstance'
        many_to_one :app, class: 'VCAP::CloudController::AppModel', key: :app_guid, primary_key: :guid, without_guid_generation: true

        def space
          relation =
            case type
            when Types::SERVICE_BINDING
              app
            else
              service_instance
            end

          relation.space
        end
      end
    end
  end
end
