module VCAP::CloudController
  class UserProvidedServiceInstance < ServiceInstance
    export_attributes :name, :credentials, :space_guid, :type, :syslog_drain_url, :route_service_url
    import_attributes :name, :credentials, :space_guid, :syslog_drain_url, :route_service_url

    # sad: can we declare this in parent class one day
    strip_attributes :name, :syslog_drain_url, :route_service_url

    add_association_dependencies service_bindings: :destroy

    def tags
      []
    end

    def route_service?
      !(route_service_url.nil? || route_service_url.empty?)
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
      return if route_service_url.blank?

      if invalid_url?
        errors.add(:service_instance, :route_service_url_invalid)
      elsif not_https?
        errors.add(:service_instance, :route_service_url_not_https)
      elsif not_valid_host?
        errors.add(:service_instance, :route_service_url_invalid)
      end
    end

    private

    def invalid_url?
      begin
        URI(route_service_url)
      rescue
        return true
      end

      false
    end

    def not_https?
      !URI(route_service_url).is_a?(URI::HTTPS)
    end

    def not_valid_host?
      (!URI(route_service_url).host || URI(route_service_url).host.to_s[0] == '.')
    end
  end
end
