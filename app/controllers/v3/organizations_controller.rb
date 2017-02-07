require 'presenters/v3/paginated_list_presenter'
require 'messages/orgs_list_message'
require 'queries/org_list_fetcher'

class OrganizationsV3Controller < ApplicationController
  include SubResource

  def index
    message = OrgsListMessage.from_params(subresource_query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    dataset = if isolation_segment_nested?
                fetch_orgs_for_isolation_segment(message)
              else
                fetch_orgs(message)
              end

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      dataset: dataset,
      path: base_url(resource: 'organizations'),
      message: message
    )
  end

  private

  def fetch_orgs(message)
    if can_read_globally?
      OrgListFetcher.new.fetch_all(message: message)
    else
      OrgListFetcher.new.fetch(message: message, guids: readable_org_guids)
    end
  end

  def fetch_orgs_for_isolation_segment(message)
    if can_read_globally?
      isolation_segment, dataset = OrgListFetcher.new.fetch_all_for_isolation_segment(message: message)
    else
      isolation_segment, dataset = OrgListFetcher.new.fetch_for_isolation_segment(message: message, guids: readable_org_guids)
    end
    isolation_segment_not_found! unless isolation_segment && can_read_isolation_segment?(isolation_segment)
    dataset
  end
end
