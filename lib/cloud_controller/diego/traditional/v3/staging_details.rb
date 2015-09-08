module VCAP::CloudController
  module Diego
    module Traditional
      module V3
        class StagingDetails
          attr_accessor :droplet, :stack, :memory_limit, :disk_limit, :buildpack_info, :environment_variables
        end
      end
    end
  end
end
