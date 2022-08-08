require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'
require 'presenters/helpers/censorship'

module VCAP::CloudController::Presenters::V3
  class DomainSharedOrgsPresenter < BasePresenter
    def initialize(
      resource,
      visible_org_guids_query: nil,
      all_orgs_visible: false
    )
      @visible_org_guids_query = visible_org_guids_query
      @all_orgs_visible = all_orgs_visible

      super(resource)
    end

    def to_hash
      {
        data: shared_org_guids
      }
    end

    private

    attr_reader :visible_org_guids_query, :all_orgs_visible

    def shared_org_guids
      ds = domain.shared_organizations_dataset
      ds = ds.where(guid: @visible_org_guids_query) unless @all_orgs_visible
      ds.select_map(:guid).map { |g| { guid: g } }
    end

    def domain
      @resource
    end
  end
end
