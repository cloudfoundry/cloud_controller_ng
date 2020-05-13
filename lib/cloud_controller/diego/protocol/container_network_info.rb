module VCAP::CloudController
  module Diego
    class Protocol
      class ContainerNetworkInfo
        attr_reader :app, :container_workload

        APP = 'app'.freeze
        STAGING = 'staging'.freeze
        TASK = 'task'.freeze

        def initialize(app, container_workload)
          @app = app
          @container_workload = container_workload
        end

        def to_h
          {
            'properties' => {
              'policy_group_id' => app.guid,
              'app_id' => app.guid,
              'space_id' => app.space.guid,
              'org_id' => app.organization.guid,
              'ports' => app.processes.map(&:open_ports).flatten.sort.uniq.join(','),
              'container_workload' => container_workload,
            },
          }
        end

        def to_bbs_network
          network = ::Diego::Bbs::Models::Network.new(properties: {})

          to_h['properties'].each do |key, value|
            network.properties[key] = value
          end

          network
        end
      end
    end
  end
end
