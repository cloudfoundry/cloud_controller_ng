module VCAP::CloudController
  class UserProvidedServiceInstance < ServiceInstance
    export_attributes :name, :credentials, :space_guid, :type
    import_attributes :name, :credentials, :space_guid

    # sad: can we declare this in parent class one day
    strip_attributes :name

    def validate
      super
      validates_presence :credentials
    end

    def unbind_on_gateway(_)
    end

    def bind_on_gateway(new_service_binding)
      new_service_binding.credentials = self.credentials
    end

    def tags
      []
    end

    def client
      ServiceBroker::UserProvided::Client.new
    end
  end
end
