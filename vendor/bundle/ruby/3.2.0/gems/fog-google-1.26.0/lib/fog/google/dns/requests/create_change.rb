module Fog
  module Google
    class DNS
      ##
      # Atomically updates a ResourceRecordSet collection.
      #
      # @see https://cloud.google.com/dns/api/v1/changes/create
      class Real
        def create_change(zone_name_or_id, additions = [], deletions = [])
          @dns.create_change(
            @project, zone_name_or_id,
            ::Google::Apis::DnsV1::Change.new(
              additions: additions,
              deletions: deletions
            )
          )
        end
      end

      class Mock
        def create_change(_zone_name_or_id, _additions = [], _deletions = [])
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
