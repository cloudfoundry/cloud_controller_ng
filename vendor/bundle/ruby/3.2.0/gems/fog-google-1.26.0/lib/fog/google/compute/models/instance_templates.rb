module Fog
  module Google
    class Compute
      class InstanceTemplates < Fog::Collection
        model Fog::Google::Compute::InstanceTemplate

        def all(opts = {})
          items = []
          next_page_token = nil
          loop do
            data = service.list_instance_templates(**opts)
            next_items = data.items || []
            items.concat(next_items)
            next_page_token = data.next_page_token
            break if next_page_token.nil? || next_page_token.empty?
            opts[:page_token] = next_page_token
          end
          load(items.map(&:to_h))
        end

        def get(identity)
          if identity
            instance_template = service.get_instance_template(identity).to_h
            return new(instance_template)
          end
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code == 404
          nil
        end
      end
    end
  end
end
