module Fog
  module Google
    class DNS
      ##
      # Enumerates Managed Zones that have been created but not yet deleted.
      #
      # @see hhttps://developers.google.com/cloud-dns/api/v1/managedZones/list
      class Real
        def list_managed_zones(dns_name: nil, max_results: nil, page_token: nil)
          @dns.list_managed_zones(@project,
                                  :dns_name => dns_name,
                                  :max_results => max_results,
                                  :page_token => page_token)
        end
      end

      class Mock
        def list_managed_zones(_opts = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
