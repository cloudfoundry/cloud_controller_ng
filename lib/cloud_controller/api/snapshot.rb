module VCAP::CloudController
  rest_controller :Snapshots do
    disable_default_routes
    path_base "snapshots"
    model_class_name :ServiceInstance

    permissions_required do
      # read Permissions::CFAdmin
      update Permissions::SpaceDeveloper
    end

    define_attributes do
      to_one :service_instance
    end
    define_messages

    def create
      req = self.class::CreateMessage.decode(body)
      instance = VCAP::CloudController::Models::ServiceInstance.find(:guid => req.service_instance_guid)
      validate_access(:update, instance, user, roles)
      gwres = instance.create_snapshot
      snapguid = "%s:%s" % [instance.guid, gwres.fetch("snapshot").fetch("id")]
      entity = {
        "guid" => snapguid,
        "state" => gwres.fetch("snapshot").fetch("state"),
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

    post "/v2/snapshots", :create
  end
end
