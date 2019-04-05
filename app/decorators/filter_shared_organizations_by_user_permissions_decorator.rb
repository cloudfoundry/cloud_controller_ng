module VCAP::CloudController
  class FilterSharedOrganizationsByUserPermissionsDecorator
    def initialize(readable_org_guids_for_user)
      @readable_org_guids_for_user = readable_org_guids_for_user
    end

    def decorate(hash, _)
      if hash.key?(:resources)
        hash[:resources] = hash[:resources].map { |h| filter_orgs(h) }
      else
        hash = filter_orgs(hash)
      end

      hash
    end

    private

    attr_reader :readable_org_guids_for_user

    def filter_orgs(hash)
      shared_org_guids = hash[:relationships][:shared_organizations][:data]
      hash[:relationships][:shared_organizations][:data] = shared_org_guids & mapped_readable_org_guids
      hash
    end

    def mapped_readable_org_guids
      @mapped_readable_org_guids ||= readable_org_guids_for_user.map { |k| { guid: k } }
    end
  end
end
