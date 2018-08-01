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
              'policy_group_id' => process.app.guid,
              'app_id' => process.app.guid,
              'space_id' => process.app.space.guid,
              'org_id' => process.app.organization.guid,
            },
          }
        end
      end
    end
  end
end
