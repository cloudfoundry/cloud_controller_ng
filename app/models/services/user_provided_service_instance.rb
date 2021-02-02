module VCAP::CloudController
  class UserProvidedServiceInstance < ServiceInstance
    export_attributes :name, :credentials, :space_guid, :type, :syslog_drain_url, :route_service_url, :tags
    import_attributes :name, :credentials, :space_guid, :syslog_drain_url, :route_service_url, :tags

    # sad: can we declare this in parent class one day
    strip_attributes :name, :syslog_drain_url, :route_service_url

    add_association_dependencies service_bindings: :destroy
    add_association_dependencies service_instance_operation: :destroy

    def route_service?
      !(route_service_url.nil? || route_service_url.empty?)
    end

    def save_with_new_operation(instance_attributes, last_operation)
      update_attributes(instance_attributes)

      if self.last_operation
        self.last_operation.destroy
      end

      # it is important to create the service instance operation with the service instance
      # instead of doing self.service_instance_operation = x
      # because mysql will deadlock when requests happen concurrently otherwise.
      ServiceInstanceOperation.create(last_operation.merge(service_instance_id: self.id))
      self.service_instance_operation(reload: true)
    end

    def validate
      validate_route_service_url
      super
    end

    def validate_route_service_url
      return if route_service_url.blank?

      if invalid_url? || not_valid_host?
        errors.add(:service_instance, :route_service_url_invalid)
      elsif not_https?
        errors.add(:service_instance, :route_service_url_not_https)
      end
    end

    def last_operation
      service_instance_operation
    end

    private

    def update_attributes(instance_attrs)
      set(instance_attrs)
      save_changes
    end

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
