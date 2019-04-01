module VCAP::CloudController
  class ServiceBindingCreateFetcher
    def fetch(app_guid, service_instance_guid)
      instance = ServiceInstance.first(guid: service_instance_guid)
      app = AppModel.first(guid: app_guid)

      [app, instance]
    end
  end
end
