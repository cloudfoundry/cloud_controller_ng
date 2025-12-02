module Fog
  module Google
    class DNS
      ##
      # Enumerates the list of Changes.
      #
      # @see https://developers.google.com/cloud-dns/api/v1/changes/list
      class Real
        def list_changes(zone_name_or_id, max_results: nil, page_token: nil,
                         sort_by: nil, sort_order: nil)
          @dns.list_changes(
            @project, zone_name_or_id,
            :max_results => max_results,
            :page_token => page_token,
            :sort_by => sort_by,
            :sort_order => sort_order
          )
        end
      end

      class Mock
        def list_changes(_zone_name_or_id, _opts = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
