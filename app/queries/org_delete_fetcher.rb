module VCAP::CloudController
  class OrganizationDeleteFetcher
    def initialize(org_guid)
      @org_guid = org_guid
    end

    def fetch
      Organization.where(guid: @org_guid)
    end
  end
end
