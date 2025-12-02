module Fog
  module Google
    class Compute
      class Mock
        def add_server_access_config(_identity, _zone, _nic, _options = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def add_server_access_config(identity, zone,
                                     network_interface,
                                     access_config_name = "External NAT",
                                     nat_ip: nil)
          @compute.add_instance_access_config(
            @project,
            zone.split("/")[-1],
            identity,
            network_interface,
            ::Google::Apis::ComputeV1::AccessConfig.new(
              name: access_config_name,
              nat_ip: nat_ip,
              type: "ONE_TO_ONE_NAT"
            )
          )
        end
      end
    end
  end
end
