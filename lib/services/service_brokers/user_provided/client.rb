module VCAP::Services
  module ServiceBrokers
    module UserProvided
      class Client
        def provision(_); end

        def bind(binding, arbitrary_parameters: nil, accepts_incomplete: nil, user_guid: nil)
          if binding.class.name.demodulize == 'RouteBinding'
            {
              async: false,
              binding: {
                route_service_url: binding.service_instance.route_service_url,
              }
            }
          else
            {
              async: false,
              binding: {
                credentials: binding.service_instance.credentials,
                syslog_drain_url: binding.service_instance.syslog_drain_url,
              }
            }
          end
        end

        def unbind(*)
          {
            async: false
          }
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
  end
end
