
module VCAP::CloudController
  rest_controller :Snapshots do
    disable_default_routes
    path_base "snapshots"

    # permissions_required do
      # read Permissions::CFAdmin
      # read Permissions::SpaceDeveloper
    # end
    def create
      payload = Yajl::Parser.parse(body)
      instance = VCAP::CloudController::Models::ServiceInstance.find(:guid => payload["service_instance_guid"])
      gwres = instance.create_snapshot("yo")
      snapguid = "%s:%s" % [instance.guid, gwres.fetch("snapshot").fetch("id")]
      entity = {
        "guid" => snapguid,
        "state" => gwres.fetch("snapshot").fetch("state"),
      }
      Yajl::Encoder.encode(
        "metadata" => {
          "url" => "/v2/snapshots/#{snapguid}",
          "guid" => snapguid,
        },
        "entity" => entity
      )
    end

    post "/v2/snapshots", :create
  end
end
