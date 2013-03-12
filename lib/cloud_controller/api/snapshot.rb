module VCAP::CloudController
  rest_controller :Snapshots do
    disable_default_routes
    path_base "/v2"
    model_class_name :ServiceInstance

    permissions_required do
      update Permissions::SpaceDeveloper
      read Permissions::SpaceDeveloper
    end

    define_attributes do
      to_one :service_instance
    end
    define_messages

    def create
      req = self.class::CreateMessage.decode(body)
      instance = VCAP::CloudController::Models::ServiceInstance.find(:guid => req.service_instance_guid)
      validate_access(:update, instance, user, roles)
      snapshot = instance.create_snapshot
      snapguid = "%s:%s" % [instance.guid, snapshot.id]
      entity = {
        "guid" => snapguid,
        "state" => snapshot.state,
      }
      [
        HTTP::CREATED,
        Yajl::Encoder.encode(
          "metadata" => {
            "url" => "/v2/snapshots/#{snapguid}",
            "guid" => snapguid,
          },
          "entity" => entity
        ),
      ]
    end

    def index(service_guid)
      instance = VCAP::CloudController::Models::ServiceInstance.find(:guid => service_guid)
      validate_access(:read, instance, user, roles)
      snapshots = instance.enum_snapshots
      [
        HTTP::OK,
        Yajl::Encoder.encode(
          "resources" => snapshots
        ),
      ]
    end

    post "/v2/snapshots", :create
    get  "/v2/service_instances/:service_guid/snapshots", :index
  end
end
