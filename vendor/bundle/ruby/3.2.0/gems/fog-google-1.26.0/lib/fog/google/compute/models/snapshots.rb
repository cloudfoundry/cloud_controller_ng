module Fog
  module Google
    class Compute
      class Snapshots < Fog::Collection
        model Fog::Google::Compute::Snapshot

        def all
          items = []
          next_page_token = nil
          loop do
            data = service.list_snapshots(:page_token => next_page_token)
            next_items = data.to_h[:items] || []
            items.concat(next_items)
            next_page_token = data.next_page_token
            break if next_page_token.nil? || next_page_token.empty?
          end
          load(items)
        end

        def get(identity)
          if identity
            snapshot = service.get_snapshot(identity).to_h
            return new(snapshot)
          end
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code == 404
          nil
        end
      end
    end
  end
end
