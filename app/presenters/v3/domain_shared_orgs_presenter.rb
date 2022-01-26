require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'
require 'presenters/helpers/censorship'

module VCAP::CloudController::Presenters::V3
  class DomainSharedOrgsPresenter < BasePresenter
    def initialize(
      resource,
        visible_org_guids: [],
        all_orgs_visible: false
    )
      @visible_org_guids = visible_org_guids
      @all_orgs_visible = all_orgs_visible

      super(resource)
    end

    def to_hash
      {
        data: shared_org_guids
      }
    end

    private

    attr_reader :visible_org_guids, :all_orgs_visible

    def shared_org_guids
      org_guids = domain.shared_organizations.map(&:guid)
      org_guids &= visible_org_guids unless all_orgs_visible
      org_guids.map { |org_guid| { guid: org_guid } }
    end

    def domain
      @resource
    end
  end
end
