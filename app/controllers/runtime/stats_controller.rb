module VCAP::CloudController
  class StatsController < RestController::ModelController
    path_base "apps"
    model_class_name :App

    get  "#{path_guid}/stats", :stats
    def stats(guid, opts = {})
      app = find_guid_and_validate_access(:read, guid)
      stats = DeaClient.find_stats(app, opts)
      [HTTP::OK, Yajl::Encoder.encode(stats)]
    end
  end
end
