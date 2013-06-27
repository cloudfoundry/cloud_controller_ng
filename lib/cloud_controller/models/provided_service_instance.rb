module VCAP::CloudController::Models
  class ProvidedServiceInstance < ServiceInstance
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
  end
end
