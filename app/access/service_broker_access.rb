module VCAP::CloudController
  class ServiceBrokerAccess < BaseAccess
    def index?(*_)
      admin_user?
    end
  end
end
