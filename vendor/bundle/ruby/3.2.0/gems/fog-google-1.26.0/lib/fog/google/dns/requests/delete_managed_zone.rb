module Fog
  module Google
    class DNS
      ##
      # Deletes a previously created Managed Zone.
      #
      # @see https://developers.google.com/cloud-dns/api/v1/managedZones/delete
      class Real
        def delete_managed_zone(name_or_id)
          @dns.delete_managed_zone(@project, name_or_id)
        end
      end

      class Mock
        def delete_managed_zone(_name_or_id)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
