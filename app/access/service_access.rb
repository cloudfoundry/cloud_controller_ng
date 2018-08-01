module VCAP::CloudController
  class ServiceAccess < BaseAccess
    def delete?(service, _=nil)
      return true if admin_user?

      unless service.nil?
        return validate_broker_access(service.service_broker)
      end

      false
    end

    private

    def validate_broker_access(service_broker)
      if service_broker.private?
        service_broker.space.has_developer?(context.user)
      else
        false
      end
    end
  end
end
