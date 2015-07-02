module VCAP::CloudController
  class ServiceBrokerAccess < BaseAccess
    def index?(*_)
      admin_user?
    end

    def create?(service_broker, _=nil)
      return true if admin_user?

      if service_broker.private?
        service_broker.space.has_developer?(context.user)
      end
    end
  end
end
