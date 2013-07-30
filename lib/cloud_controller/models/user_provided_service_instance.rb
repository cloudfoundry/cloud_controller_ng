module VCAP::CloudController::Models
  class UserProvidedServiceInstance < ServiceInstance
    export_attributes :name, :credentials, :space_guid
    import_attributes :name, :credentials, :space_guid

    # sad: can we declare this in parent class one day
    strip_attributes :name

    def validate
      super
      validates_presence :credentials
    end

    def as_summary_json
      {
        "guid" => guid,
        "name" => name
      }
    end

    def unbind_on_gateway(_)
    end

    def bind_on_gateway(new_service_binding)
      new_service_binding.credentials = self.credentials
    end

    def bindable?
      true
    end

    def tags
      []
    end
  end
end
