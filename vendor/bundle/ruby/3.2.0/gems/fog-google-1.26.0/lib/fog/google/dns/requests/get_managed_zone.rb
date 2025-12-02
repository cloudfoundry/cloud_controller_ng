module Fog
  module Google
    class DNS
      ##
      # Fetches the representation of an existing Managed Zone.
      #
      # @see https://developers.google.com/cloud-dns/api/v1/managedZones/get
      class Real
        def get_managed_zone(name_or_id)
          @dns.get_managed_zone(@project, name_or_id)
        end
      end

      class Mock
        def get_managed_zone(_name_or_id)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
