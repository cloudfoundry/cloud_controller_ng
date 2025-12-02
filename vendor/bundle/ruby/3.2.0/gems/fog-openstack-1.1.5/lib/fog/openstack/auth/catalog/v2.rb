require 'fog/openstack/auth/catalog'

module Fog
  module OpenStack
    module Auth
      module Catalog
        class V2
          include Fog::OpenStack::Auth::Catalog

          def endpoint_match?(endpoint, interface, region)
            if endpoint.key?("#{interface}URL")
              true unless !region.nil? && endpoint['region'] != region
            end
          end

          def endpoint_url(endpoint, interface)
            endpoint["#{interface}URL"]
          end
        end
      end
    end
  end
end
