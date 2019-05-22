require 'messages/route_create_message'
require 'messages/route_show_message'
require 'messages/routes_list_message'
require 'presenters/v3/route_presenter'
require 'presenters/v3/paginated_list_presenter'
require 'actions/route_create'
require 'actions/route_delete'
require 'fetchers/route_fetcher'

class RoutesController < ApplicationController
  def index
    message = RoutesListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    dataset = RouteFetcher.fetch(message, permission_queryer.readable_route_guids)

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::RoutePresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: '/v3/routes',
      message: message,
    )
  end

  def show
    message = RouteShowMessage.new({ guid: hashed_params['guid'] })
    unprocessable!(message.errors.full_messages) unless message.valid?

    route = Route.find(guid: message.guid)
    route_not_found! unless route && permission_queryer.can_read_route?(route.space.guid, route.organization.guid)

    render status: :ok, json: Presenters::V3::RoutePresenter.new(route)
  end

  def create
    FeatureFlag.raise_unless_enabled!(:route_creation) unless permission_queryer.can_write_globally?

    message = RouteCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    space = Space.find(guid: message.space_guid)
    domain = Domain.find(guid: message.domain_guid)

    unprocessable_space! unless space
    unprocessable_domain! unless domain
    unauthorized! unless permission_queryer.can_write_to_space?(space.guid)
    unprocessable_wildcard! if domain.shared? && message.wildcard? && !permission_queryer.can_write_globally?

    route = RouteCreate.new(user_audit_info).create(message: message, space: space, domain: domain)

    render status: :created, json: Presenters::V3::RoutePresenter.new(route)
  rescue RouteCreate::Error => e
    unprocessable!(e)
  end

  def destroy
    message = RouteShowMessage.new({ guid: hashed_params['guid'] })
    unprocessable!(message.errors.full_messages) unless message.valid?

    route = Route.find(guid: message.guid)
    route_not_found! unless route && permission_queryer.can_read_route?(route.space.guid, route.organization.guid)
    unauthorized! unless permission_queryer.can_write_to_space?(route.space.guid)

    delete_action = RouteDeleteAction.new
    deletion_job = VCAP::CloudController::Jobs::DeleteActionJob.new(Route, route.guid, delete_action)
    pollable_job = Jobs::Enqueuer.new(deletion_job, queue: 'cc-generic').enqueue_pollable

    url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new
    head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{pollable_job.guid}")
  end

  private

  def route_not_found!
    resource_not_found!(:route)
  end

  def unprocessable_wildcard!
    unprocessable!('You do not have sufficient permissions to create a route with a wildcard host on a domain not scoped to an organization.')
  end

  def unprocessable_space!
    unprocessable!('Invalid space. Ensure that the space exists and you have access to it.')
  end

  def unprocessable_domain!
    unprocessable!('Invalid domain. Ensure that the domain exists and you have access to it.')
  end
end
