module VCAP::CloudController
  class IsolationSegmentOrganizationsFetcher
    def initialize(isolation_segment)
      @isolation_segment = isolation_segment
    end

    def fetch_all
      @isolation_segment.organizations
    end

    def fetch_for_organizations(org_guids_query:)
      Organization.where(guid: org_guids_query, isolation_segment_models: @isolation_segment).all
    end
  end
end
