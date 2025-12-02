module Fog
  module Google
    class Compute
      class Mock
        def patch_firewall(_firewall_name, _firewall_opts = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        ##
        # Patch a Firewall resource. Supports PATCH semantics.
        #
        # @see https://cloud.google.com/compute/docs/reference/latest/firewalls/patch
        def patch_firewall(firewall_name, opts = {})
          opts = opts.select { |k, _| UPDATABLE_FIREWALL_FIELDS.include? k }
          @compute.patch_firewall(
            @project, firewall_name,
            ::Google::Apis::ComputeV1::Firewall.new(**opts)
          )
        end
      end
    end
  end
end
