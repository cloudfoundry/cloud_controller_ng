module VCAP::CloudController
  class SpaceDeleteFetcher
    def initialize(space_guid)
      @space_guid = space_guid
    end

    def fetch
      Space.where(guid: @space_guid)
    end
  end
end
