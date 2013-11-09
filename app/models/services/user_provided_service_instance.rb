module VCAP::CloudController
  class UserProvidedServiceInstance < ServiceInstance
    export_attributes :name, :credentials, :space_guid, :type, :syslog_drain_url
    import_attributes :name, :credentials, :space_guid, :syslog_drain_url

    # sad: can we declare this in parent class one day
    strip_attributes :name, :syslog_drain_url

    add_association_dependencies :service_bindings => :destroy

    def validate
      super
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
