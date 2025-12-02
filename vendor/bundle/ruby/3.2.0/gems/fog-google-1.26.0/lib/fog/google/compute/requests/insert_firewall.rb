module Fog
  module Google
    class Compute
      class Mock
        def insert_firewall(_firewall_name, _options = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        INSERTABLE_FIREWALL_FIELDS = %i{
          allowed
          denied
          description
          destination_ranges
          direction
          name
          network
          priority
          source_ranges
          source_service_accounts
          source_tags
          target_service_accounts
          target_tags
        }.freeze

        ##
        # Create a Firewall resource
        #
        # @param [Hash] opts The firewall object to create
        # @option opts [Array<Hash>] allowed
        # @option opts [Array<Hash>] denied
        # @option opts [String] description
        # @option opts [Array<String>] destination_ranges
        # @option opts [String] direction
        # @option opts [String] name
        # @option opts [String] network
        # @option opts [Fixnum] priority
        # @option opts [Array<String>] source_ranges
        # @option opts [Array<String>] source_service_accounts
        # @option opts [Array<String>] source_tags
        # @option opts [Array<String>] target_service_accounts
        # @option opts [Array<String>] target_tags
        #
        # @see https://cloud.google.com/compute/docs/reference/latest/firewalls/insert
        def insert_firewall(firewall_name, opts = {})
          if opts.key?(:network) && !opts[:network].empty?
            unless opts[:network].start_with?("http://", "https://", "projects/", "global/")
              opts[:network] = "projects/#{@project}/global/networks/#{opts[:network]}"
            end
          end

          opts = opts.select { |k, _| INSERTABLE_FIREWALL_FIELDS.include? k }
                     .merge(:name => firewall_name)

          @compute.insert_firewall(
            @project, ::Google::Apis::ComputeV1::Firewall.new(**opts)
          )
        end
      end
    end
  end
end
