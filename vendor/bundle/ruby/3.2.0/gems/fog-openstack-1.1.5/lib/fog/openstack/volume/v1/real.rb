module Fog
  module OpenStack
    class Volume
      class V1 < Fog::OpenStack::Volume
        class Real
          include Fog::OpenStack::Core

          def self.not_found_class
            Fog::OpenStack::Volume::NotFound
          end

          def default_endtpoint_type
            'admin'
          end

          def default_service_type
            %w[volume]
          end
        end
      end
    end
  end
end
