module VCAP::CloudController
  rest_controller :Stats do
    disable_default_routes
    path_base "apps"
    model_class_name :App

    def stats(guid, opts = {})
      app = find_guid_and_validate_access(:read, guid)
      stats = DeaClient.find_stats(app, opts)
      [HTTP::OK, Yajl::Encoder.encode(stats)]
    end

    get  "#{path_guid}/stats", :stats
  end
end
