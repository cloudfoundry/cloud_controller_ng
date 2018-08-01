module VCAP::CloudController
  class ServiceBrokerAccess < BaseAccess
    def create?(service_broker, _=nil)
      return true if admin_user?
      FeatureFlag.raise_unless_enabled!(:space_scoped_private_broker_creation)

      unless service_broker.nil?
        return validate_object_access(service_broker)
      end
    end

    def update?(service_broker, _=nil)
      return true if admin_user?

      unless service_broker.nil?
        return validate_object_access(service_broker)
      end

      false
    end

    def delete?(service_broker, _=nil)
      return true if admin_user?

      unless service_broker.nil?
        return validate_object_access(service_broker)
      end

      false
    end

    private

    def validate_object_access(service_broker)
      if service_broker.private?
        service_broker.space.has_developer?(context.user)
      else
        false
      end
    end
  end
end
