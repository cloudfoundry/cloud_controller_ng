module Fog
  module Google
    class DNS
      class Zones < Fog::Collection
        model Fog::Google::DNS::Zone

        ##
        # Enumerates Managed Zones that have been created but not yet deleted
        #
        # @return [Array<Fog::Google::DNS::Zone>] List of Managed Zone resources
        def all
          data = service.list_managed_zones.managed_zones.to_h || []
          load(data)
        end

        ##
        # Fetches the representation of an existing Managed Zone
        #
        # @param [String] name_or_id Managed Zone name or identity
        # @return [Fog::Google::DNS::Zone] Managed Zone resource
        def get(name_or_id)
          if zone = service.get_managed_zone(name_or_id).to_h
            new(zone)
          end
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code == 404

          nil
        end
      end
    end
  end
end
