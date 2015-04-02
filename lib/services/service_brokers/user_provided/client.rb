module VCAP::Services
  class ServiceBrokers::UserProvided::Client
    def provision(_)
    end

    def bind(binding)
      {
        credentials: binding.service_instance.credentials,
        syslog_drain_url: binding.service_instance.syslog_drain_url
      }
    end

    def unbind(_)
    end

    def deprovision(_, _={})
    end
  end
end
