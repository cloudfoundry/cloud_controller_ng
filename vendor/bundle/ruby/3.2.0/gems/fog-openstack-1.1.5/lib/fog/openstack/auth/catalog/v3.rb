require 'fog/openstack/auth/catalog'

module Fog
  module OpenStack
    module Auth
      module Catalog
        class V3
          include Fog::OpenStack::Auth::Catalog

          def endpoint_match?(endpoint, interface, region)
            if endpoint['interface'] == interface
              true unless !region.nil? && endpoint['region'] != region
            end
          end

          def endpoint_url(endpoint, _)
            endpoint['url']
          end
        end
      end
    end
  end
end
