module VCAP::CloudController
  module Jobs
    module V3
      class SpaceDeleteUnmappedRoutesJob
        attr_reader :space_guid
        alias_method :resource_guid, :space_guid

        def initialize(space)
          @space = space
          @space_guid = space.guid
        end

        def perform
          VCAP::CloudController::SpaceDeleteUnmappedRoutes.new.delete(@space)
        end

        def display_name
          'space.delete_unmapped_routes'
        end

        def resource_type
          'space'
        end
      end
    end
  end
end
