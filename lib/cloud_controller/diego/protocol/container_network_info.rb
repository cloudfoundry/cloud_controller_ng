module VCAP::CloudController
  module Diego
    class Protocol
      class ContainerNetworkInfo
        attr_reader :app

        def initialize(app)
          @app = app
        end

        def to_h
          {
            'properties' => {
              'policy_group_id' => app.guid,
              'app_id' => app.guid,
              'space_id' => app.space.guid,
              'org_id' => app.organization.guid,
            },
          }
        end

        def to_bbs_network
          network = ::Diego::Bbs::Models::Network.new(properties: [])

          to_h['properties'].each do |key, value|
            network.properties << ::Diego::Bbs::Models::Network::PropertiesEntry.new(
              key:   key,
              value: value,
            )
          end

          network
        end
      end
    end
  end
end
