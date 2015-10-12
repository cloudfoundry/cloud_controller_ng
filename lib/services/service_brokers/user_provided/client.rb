module VCAP::Services
  class ServiceBrokers::UserProvided::Client
    def provision(_)
    end

    def bind(binding, arbitrary_parameters: {})
      if binding.class.name.demodulize == 'RouteBinding'
        {
          route_service_url: binding.service_instance.route_service_url,
        }
      else
        {
          credentials: binding.service_instance.credentials,
          syslog_drain_url: binding.service_instance.syslog_drain_url,
        }
      end
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
