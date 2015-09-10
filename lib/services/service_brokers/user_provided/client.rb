module VCAP::Services
  class ServiceBrokers::UserProvided::Client
    def provision(_)
    end

    def bind(binding, arbitrary_parameters: {})
      {
        credentials: binding.service_instance.credentials,
        syslog_drain_url: binding.service_instance.syslog_drain_url
      }
    end

    def unbind(_)
    end

    def deprovision(_, _={})
      {
        last_operation: {
          state: 'succeeded'
        }
      }
    end
  end
end
