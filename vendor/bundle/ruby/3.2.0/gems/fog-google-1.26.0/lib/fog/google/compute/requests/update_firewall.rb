module Fog
  module Google
    class Compute
      class Mock
        def update_firewall(_firewall_name, _firewall_opts = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        UPDATABLE_FIREWALL_FIELDS = %i{
          allowed
          description
          source_ranges
          source_service_accounts
          source_tags
          target_service_accounts
          target_tags
        }.freeze

        ##
        # Update a Firewall resource.
        #
        # Only the following fields can/will be changed.
        #
        # @param [Hash] opts The firewall object to create
        # @option opts [Array<Hash>] allowed
        # @option opts [String] description
        # @option opts [Array<String>] destination_ranges
        # @option opts [Array<String>] source_ranges
        # @option opts [Array<String>] source_service_accounts
        # @option opts [Array<String>] source_tags
        # @option opts [Array<String>] target_service_accounts
        # @option opts [Array<String>] target_tags
        #
        # @see https://cloud.google.com/compute/docs/reference/latest/firewalls/insert
        def update_firewall(firewall_name, opts = {})
          opts = opts.select { |k, _| UPDATABLE_FIREWALL_FIELDS.include? k }
          @compute.update_firewall(
            @project, firewall_name,
            ::Google::Apis::ComputeV1::Firewall.new(**opts)
          )
        end
      end
    end
  end
end
