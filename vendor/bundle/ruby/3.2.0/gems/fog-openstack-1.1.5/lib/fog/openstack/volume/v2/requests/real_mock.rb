module Fog
  module OpenStack
    class Volume
      class V2
        class Real
          include Fog::OpenStack::Volume::Real
        end
        class Mock
          include Fog::OpenStack::Volume::Mock
        end
      end
    end
  end
end
