require 'presenters/v3/paginated_list_presenter'
require 'messages/orgs_list_message'
require 'queries/org_list_fetcher'

class OrganizationsV3Controller < ApplicationController
  def index
    message = OrgsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      dataset: readable_orgs(message),
      path: '/v3/organizations',
      message: message
    )
  end

  private

  def readable_orgs(message)
    if can_read_globally?
      OrgListFetcher.new.fetch_all(message: message)
    else
      OrgListFetcher.new.fetch(message: message, guids: readable_org_guids)
    end
  end
end
