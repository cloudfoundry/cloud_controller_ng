module Fog
  module Google
    class Compute
      class Mock
        def insert_instance_group(_group_name, _zone, _options = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def insert_instance_group(group_name, zone, options = {})
          if options["network"]
            network_name = last_url_segment(options["network"])
          else
            network_name = GOOGLE_COMPUTE_DEFAULT_NETWORK
          end

          instance_group = ::Google::Apis::ComputeV1::InstanceGroup.new(
            description: options["description"],
            name: group_name,
            network: "https://www.googleapis.com/compute/#{api_version}/projects/#{@project}/global/networks/#{network_name}"
          )

          @compute.insert_instance_group(@project,
                                         last_url_segment(zone),
                                         instance_group)
        end

        def last_url_segment(network)
          network.split("/")[-1]
        end
      end
    end
  end
end
