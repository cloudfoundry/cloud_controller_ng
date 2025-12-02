module Fog
  module Google
    class DNS
      ##
      # Fetches the representation of an existing Change.
      #
      # @see https://developers.google.com/cloud-dns/api/v1/changes/get
      class Real
        def get_change(zone_name_or_id, identity)
          @dns.get_change(@project, zone_name_or_id, identity)
        end
      end

      class Mock
        def get_change(_zone_name_or_id, _identity)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
