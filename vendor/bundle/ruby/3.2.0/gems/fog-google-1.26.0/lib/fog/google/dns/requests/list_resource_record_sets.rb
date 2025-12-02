module Fog
  module Google
    class DNS
      ##
      # Enumerates Resource Record Sets that have been created but not yet deleted.
      #
      # @see https://developers.google.com/cloud-dns/api/v1/resourceRecordSets/list
      class Real
        def list_resource_record_sets(zone_name_or_id, max_results: nil,
                                      name: nil, page_token: nil, type: nil)
          @dns.list_resource_record_sets(
            @project, zone_name_or_id,
            :max_results => max_results,
            :name => name,
            :page_token => page_token,
            :type => type
          )
        end
      end

      class Mock
        def list_resource_record_sets(_zone_name_or_id, _options = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
