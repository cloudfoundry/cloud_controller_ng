module VCAP::CloudController
  class UserProvidedServiceInstance < ServiceInstance
    class InvalidRouteServiceUrlScheme < StandardError; end

    export_attributes :name, :credentials, :space_guid, :type, :syslog_drain_url, :route_service_url
    import_attributes :name, :credentials, :space_guid, :syslog_drain_url, :route_service_url

    # sad: can we declare this in parent class one day
    strip_attributes :name, :syslog_drain_url, :route_service_url

    add_association_dependencies service_bindings: :destroy

    def tags
      []
    end

    def client
      VCAP::Services::ServiceBrokers::UserProvided::Client.new
    end

    def save_with_new_operation(_, _)
    end

    def validate
      validate_route_service_url
      super
    end

    def validate_route_service_url
      return if route_service_url == ''

      if route_service_url && URI(route_service_url).scheme.to_s.downcase != 'https'
        raise InvalidRouteServiceUrlScheme.new(:route_service_url)
      end
    end
  end
end
