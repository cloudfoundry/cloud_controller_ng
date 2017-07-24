module VCAP::CloudController
  class SpaceFetcher
    def fetch(space_guid)
      Space.find(guid: space_guid)
    end
  end
end
