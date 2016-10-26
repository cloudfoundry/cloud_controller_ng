module VCAP::CloudController
  class IsolationSegmentSpacesFetcher
    def initialize(isolation_segment)
      @isolation_segment = isolation_segment
    end

    def fetch_all
      @isolation_segment.spaces
    end

    def fetch_for_spaces(space_guids:)
      Space.where(guid: space_guids, isolation_segment_model: @isolation_segment).all
    end
  end
end
