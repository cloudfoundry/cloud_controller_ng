require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'
require 'presenters/helpers/censorship'

module VCAP::CloudController::Presenters::V3
  class DomainSharedOrgsPresenter < BasePresenter
    def initialize(
      resource,
      visible_org_guids_for_shared_orgs: Set.new,
      all_orgs_visible: false
    )
      @visible_org_guids_for_shared_orgs = visible_org_guids_for_shared_orgs
      @all_orgs_visible = all_orgs_visible

      super(resource)
    end

    def to_hash
      {
        data: shared_org_guids
      }
    end

    private

    attr_reader :visible_org_guids_for_shared_orgs, :all_orgs_visible

    def shared_org_guids
      orgs = domain.shared_organizations
      orgs = orgs.select { |org| visible_org_guids_for_shared_orgs.include?(org.guid) } unless all_orgs_visible
      orgs.map { |org| { guid: org.guid } }
    end

    def domain
      @resource
    end
  end
end
