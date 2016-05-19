module VCAP::CloudController
  module Diego
    module V3
      class StagingDetails
        attr_accessor :droplet, :memory_limit, :disk_limit, :environment_variables, :lifecycle
      end
    end
  end
end
