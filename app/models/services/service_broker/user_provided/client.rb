module VCAP::CloudController
  class ServiceBroker::UserProvided::Client
    def provision(_)
    end

    def bind(binding)
      binding.credentials = binding.service_instance.credentials
      binding.syslog_drain_url = binding.service_instance.syslog_drain_url
    end

    def unbind(_)
    end

    def deprovision(_)
    end
  end
end
