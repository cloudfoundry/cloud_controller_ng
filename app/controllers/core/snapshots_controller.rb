module VCAP::CloudController
  rest_controller :Snapshots do
    disable_default_routes
    path_base "/v2"
    model_class_name :ManagedServiceInstance

    define_attributes do
      attribute :name, String
      to_one :service_instance
    end
    define_messages

    def create
      req = self.class::CreateMessage.decode(body)
      instance = VCAP::CloudController::Models::ManagedServiceInstance.find(:guid => req.service_instance_guid)
      validate_access(:update, instance, user, roles)
      snapshot = instance.create_snapshot(req.name)
      snap_guid = "%s_%s" % [instance.guid, snapshot.snapshot_id]
      [
        HTTP::CREATED,
        Yajl::Encoder.encode(
          "metadata" => {
            "url" => "/v2/snapshots/#{snap_guid}",
            "guid" => snap_guid,
            "created_at" => snapshot.created_time,
            "updated_at" => nil
          },
          "entity" => snapshot.extract
        ),
      ]
    end

    def index(service_guid)
      instance = VCAP::CloudController::Models::ManagedServiceInstance.find(:guid => service_guid)
      validate_access(:read, instance, user, roles)
      snapshots = instance.enum_snapshots
      [
        HTTP::OK,
        Yajl::Encoder.encode(
          "total_results" => snapshots.length,
          "total_pages" => 1,
          "prev_url" => nil,
          "next_url" => nil,
          "resources" => snapshots.collect do |s|
            {
              "metadata" => {
                "guid" => "#{service_guid}_#{s.snapshot_id}",
                "url" => "/v2/snapshots/#{service_guid}_#{s.snapshot_id}",
                "created_at" => s.created_time,
                "updated_at" => nil,
              },
              "entity" => s.extract
            }
          end
        ),
      ]
    end

    post "/v2/snapshots", :create
    get  "/v2/service_instances/:service_guid/snapshots", :index
  end
end
