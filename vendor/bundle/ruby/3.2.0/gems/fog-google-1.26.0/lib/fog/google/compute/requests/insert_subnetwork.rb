module Fog
  module Google
    class Compute
      class Mock
        def insert_subnetwork(_subnetwork_name, _region_name, _network, _ip_range, _options = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        ##
        # Create a subnetwork.
        #
        # @param subnetwork_name [String] the name of the subnetwork
        # @param region_name [String] the name of the subnetwork's region
        # @param network [String] URL of the network this subnetwork belongs to
        # @param ip_range [String] The range of internal addresses that are owned
        #   by this subnetwork.
        # @param options [Hash] Other optional attributes to set on the subnetwork
        # @option options [Boolean] private_ip_google_access Whether the VMs in
        #   this subnet can access Google services without assigned external IP
        #   addresses.
        # @option options [String] description An optional description of this resource.
        # @option options [Array<Hash>] secondary_ip_ranges An array of configurations
        #   for secondary IP ranges
        # @option secondary_ip_ranges [String] ip_cidr_range The range of IP
        #   addresses for a secondary range
        # @option secondary_ip_ranges [String] range_name The name associated
        #   with a secondary range
        #
        # @return [Google::Apis::ComputeV1::Operation] an operation response
        #
        # @see https://cloud.google.com/compute/docs/reference/latest/subnetworks/insert
        def insert_subnetwork(subnetwork_name, region_name, network, ip_range, options = {})
          region_name = region_name.split("/")[-1] if region_name.start_with? "http"
          unless network.start_with? "http"
            network = "#{@api_url}#{@project}/global/networks/#{network}"
          end

          params = {
            :name => subnetwork_name,
            :ip_cidr_range => ip_range,
            :region => region_name,
            :network => network
          }

          optional_fields = %i{private_ip_google_access description secondary_ip_ranges}
          params = optional_fields.inject(params) do |data, field|
            data[field] = options[field] unless options[field].nil?
            data
          end

          subnetwork = ::Google::Apis::ComputeV1::Subnetwork.new(**params)
          @compute.insert_subnetwork(@project, region_name, subnetwork)
        end
      end
    end
  end
end
