module VCAP::CloudController
  module Diego
    class Protocol
      class ContainerNetworkInfo
        attr_reader :process

        def initialize(process)
          @process = process
        end

        def to_h
          {
            'properties' => {
              'policy_group_id' => process.guid,
              'app_id' => process.guid,
              'space_id' => process.space.guid,
              'org_id' => process.organization.guid,
            },
          }
        end
      end
    end
  end
end
