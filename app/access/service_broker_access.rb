module VCAP::CloudController
  class ServiceBrokerAccess < BaseAccess
    def create?(service_broker, _=nil)
      return true if admin_user?

      if service_broker.is_a? Object
        return validate_object_access(service_broker)
      end
    end

    def update?(service_broker, _=nil)
      return true if admin_user?

      if service_broker.is_a? Object
        return validate_object_access(service_broker)
      end

      false
    end

    def validate_object_access(service_broker)
      if service_broker.private?
        service_broker.space.has_developer?(context.user)
      else
        false
      end
    end
  end
end
