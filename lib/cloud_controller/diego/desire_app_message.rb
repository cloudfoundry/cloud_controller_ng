module VCAP::CloudController
  module Diego
    class DesireAppMessage < JsonMessage
      required :process_guid, String
      required :memory_mb, Integer
      required :disk_mb, Integer
      required :file_descriptors, Integer
      required :droplet_uri, String
      required :stack, String
      required :start_command, String
      required :environment, [{
        name: String,
        value: String,
      }]
      required :num_instances, Integer
      required :routes, [String]
      optional :health_check_timeout_in_seconds, Integer
      required :log_guid, String
    end
  end
end
