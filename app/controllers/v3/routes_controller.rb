require 'messages/route_destinations_list_message'
require 'messages/route_create_message'
require 'messages/route_destination_update_message'
require 'messages/routes_list_message'
require 'messages/route_show_message'
require 'messages/route_update_message'
require 'messages/route_transfer_owner_message'
require 'messages/route_update_destinations_message'
require 'actions/update_route_destinations'
require 'decorators/include_route_domain_decorator'
require 'presenters/v3/route_presenter'
require 'presenters/v3/route_destinations_presenter'
require 'presenters/v3/paginated_list_presenter'
require 'actions/route_destination_update'
require 'actions/route_create'
require 'actions/route_delete'
require 'actions/route_update'
require 'actions/route_share'
require 'actions/route_unshare'
require 'actions/route_transfer_owner'
require 'fetchers/app_fetcher'
require 'fetchers/route_fetcher'
require 'fetchers/route_destinations_list_fetcher'

class RoutesController < ApplicationController
  def index
    message = RoutesListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    dataset = if permission_queryer.can_read_globally?
                RouteFetcher.fetch(
                  message,
                  omniscient: true,
                  eager_loaded_associations: Presenters::V3::RoutePresenter.associated_resources
                )
              else
                RouteFetcher.fetch(
                  message,
                  readable_space_guids_dataset: permission_queryer.space_guids_with_readable_routes_query,
                  eager_loaded_associations: Presenters::V3::RoutePresenter.associated_resources
                )
              end

    decorators = []
    decorators << IncludeRouteDomainDecorator if IncludeRouteDomainDecorator.match?(message.include)
    decorators << IncludeSpaceDecorator if IncludeSpaceDecorator.match?(message.include)
    decorators << IncludeOrganizationDecorator if IncludeOrganizationDecorator.match?(message.include)

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::RoutePresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: '/v3/routes',
      message: message,
      decorators: decorators,
    )
  end

  def show
    message = RouteShowMessage.from_params(query_params.merge(guid: hashed_params[:guid]))
    unprocessable!(message.errors.full_messages) unless message.valid?

    decorators = []
    decorators << IncludeRouteDomainDecorator if IncludeRouteDomainDecorator.match?(message.include)
    decorators << IncludeSpaceDecorator if IncludeSpaceDecorator.match?(message.include)
    decorators << IncludeOrganizationDecorator if IncludeOrganizationDecorator.match?(message.include)

    render status: :ok, json: Presenters::V3::RoutePresenter.new(
      route,
      decorators: decorators,
    )
  end

  def create
    FeatureFlag.raise_unless_enabled!(:route_creation) unless permission_queryer.can_write_globally?

    message = RouteCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    space = Space.find(guid: message.space_guid)
    domain = Domain.find(guid: message.domain_guid)

    unprocessable_space! unless space
    unprocessable_domain! unless domain
    unauthorized! unless permission_queryer.can_manage_apps_in_active_space?(space.id)
    suspended! unless permission_queryer.is_space_active?(space.id)
    unprocessable_wildcard! if domain.shared? && message.wildcard? && !permission_queryer.can_write_globally?

    route = RouteCreate.new(user_audit_info).create(message: message, space: space, domain: domain)

    render status: :created, json: Presenters::V3::RoutePresenter.new(route)
  rescue RoutingApi::UaaUnavailable, UaaUnavailable
    service_unavailable!('Communicating with the Routing API failed because UAA is currently unavailable. Please try again later.')
  rescue RoutingApi::RoutingApiUnavailable
    service_unavailable!('The Routing API is currently unavailable. Please try again later.')
  rescue RoutingApi::RoutingApiDisabled
    service_unavailable!('The Routing API is disabled.')
  rescue RouteCreate::Error => e
    unprocessable!(e)
  end

  def update
    message = RouteUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    unauthorized! unless permission_queryer.can_manage_apps_in_active_space?(route.space_id)
    suspended! unless permission_queryer.is_space_active?(route.space_id)

    VCAP::CloudController::RouteUpdate.new.update(route: route, message: message)

    render status: :ok, json: Presenters::V3::RoutePresenter.new(route)
  end

  def destroy
    message = RouteShowMessage.from_params({ guid: hashed_params['guid'] })
    unprocessable!(message.errors.full_messages) unless message.valid?

    unauthorized! unless permission_queryer.can_manage_apps_in_active_space?(route.space_id)
    suspended! unless permission_queryer.is_space_active?(route.space_id)

    delete_action = RouteDeleteAction.new(user_audit_info)
    deletion_job = VCAP::CloudController::Jobs::DeleteActionJob.new(Route, route.guid, delete_action)
    pollable_job = Jobs::Enqueuer.new(deletion_job, queue: Jobs::Queues.generic).enqueue_pollable

    head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{pollable_job.guid}")
  end

  def share_routes
    FeatureFlag.raise_unless_enabled!(:route_sharing)

    unauthorized! unless permission_queryer.can_manage_apps_in_active_space?(route.space_id)
    suspended! unless permission_queryer.is_space_active?(route.space_id)

    message = VCAP::CloudController::ToManyRelationshipMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    target_spaces = Space.where(guid: message.guids)
    check_spaces_exist_and_are_writeable!(route, message.guids, target_spaces)

    share = RouteShare.new
    share.create(route, target_spaces, user_audit_info)

    render status: :ok, json: Presenters::V3::ToManyRelationshipPresenter.new(
      "routes/#{route.guid}", route.shared_spaces, 'shared_spaces', build_related: false)
  rescue VCAP::CloudController::RouteShare::Error => e
    unprocessable!(e.message)
  end

  def unshare_route
    FeatureFlag.raise_unless_enabled!(:route_sharing)
    unauthorized! unless permission_queryer.can_manage_apps_in_active_space?(route.space_id)
    suspended! unless permission_queryer.is_space_active?(route.space_id)

    space_guid = hashed_params[:space_guid]

    target_space = Space.first(guid: space_guid)
    target_space_error = check_if_space_is_accessible(target_space)
    unprocessable!("Unable to unshare route '#{route.uri}' from space '#{space_guid}'. #{target_space_error}") unless target_space_error.nil?

    unshare = RouteUnshare.new
    unshare.unshare(route, target_space, user_audit_info)

    head :no_content
  rescue VCAP::CloudController::RouteUnshare::Error => e
    unprocessable!(e.message)
  end

  def relationships_shared_routes
    FeatureFlag.raise_unless_enabled!(:route_sharing)

    render status: :ok, json: Presenters::V3::ToManyRelationshipPresenter.new(
      "routes/#{route.guid}", route.shared_spaces, 'shared_spaces', build_related: false)
  end

  def transfer_owner
    FeatureFlag.raise_unless_enabled!(:route_sharing)

    message = RouteTransferOwnerMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    unauthorized! unless permission_queryer.can_write_to_active_space?(route.space_id)
    suspended! unless permission_queryer.is_space_active?(route.space_id)

    target_space = Space.first(guid: message.space_guid)
    target_space_error = check_if_space_is_accessible(target_space)
    unprocessable!("Unable to transfer owner of route '#{route.uri}' to space '#{message.space_guid}'. #{target_space_error}") unless target_space_error.nil?

    if !route.domain.usable_by_organization?(target_space.organization)
      unprocessable!("Unable to transfer owner of route '#{route.uri}' to space '#{message.space_guid}'. Target space does not have access to route's domain")
    end

    RouteTransferOwner.transfer(route, target_space, user_audit_info)

    render status: :ok, json: { status: 'ok' }
  end

  def index_destinations
    message = RouteShowMessage.from_params({ guid: hashed_params['guid'] })
    unprocessable!(message.errors.full_messages) unless message.valid?

    destinations_message = RouteDestinationsListMessage.from_params(query_params)
    unprocessable!(destinations_message.errors.full_messages) unless destinations_message.valid?
    route_mappings = RouteDestinationsListFetcher.new(message: destinations_message).fetch_for_route(route: route)

    render status: :ok, json: Presenters::V3::RouteDestinationsPresenter.new(route_mappings, route: route)
  end

  def insert_destinations
    message = RouteUpdateDestinationsMessage.new(hashed_params[:body])

    unprocessable!(message.errors.full_messages) unless message.valid?
    unauthorized! unless permission_queryer.can_manage_apps_in_active_space?(route.space_id)
    suspended! unless permission_queryer.is_space_active?(route.space_id)

    UpdateRouteDestinations.add(message.destinations_array, route, apps_hash(message), user_audit_info)

    render status: :ok, json: Presenters::V3::RouteDestinationsPresenter.new(route.route_mappings, route: route)
  rescue UpdateRouteDestinations::Error => e
    unprocessable!(e.message)
  end

  def replace_destinations
    message = RouteUpdateDestinationsMessage.new(hashed_params[:body], replace: true)

    unprocessable!(message.errors.full_messages) unless message.valid?
    unauthorized! unless permission_queryer.can_manage_apps_in_active_space?(route.space_id)
    suspended! unless permission_queryer.is_space_active?(route.space_id)

    UpdateRouteDestinations.replace(message.destinations_array, route, apps_hash(message), user_audit_info)

    render status: :ok, json: Presenters::V3::RouteDestinationsPresenter.new(route.route_mappings, route: route)
  rescue UpdateRouteDestinations::DuplicateDestinationError => e
    unprocessable!(e.message)
  end

  def update_destination
    message = RouteDestinationUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    route = Route.find(guid: hashed_params[:guid])
    route_not_found! unless route && permission_queryer.can_read_route?(route.space_id)
    unauthorized! unless permission_queryer.can_manage_apps_in_active_space?(route.space_id)
    suspended! unless permission_queryer.is_space_active?(route.space_id)

    destination = RouteMappingModel.find(guid: hashed_params[:destination_guid])
    unprocessable_destination! unless destination

    RouteDestinationUpdate.update(destination, message)

    render status: :ok, json: Presenters::V3::RouteDestinationPresenter.new(destination)
  rescue RouteDestinationUpdate::Error => e
    unprocessable!(e.message)
  end

  def route
    @route || begin
      @route = Route.find(guid: hashed_params[:guid])
      route_not_found! unless @route && permission_queryer.can_read_route?(@route.space_id)
      @route
    end
  end

  def apps_hash(update_message)
    @apps_hash || begin
      desired_app_guids = update_message.destinations.map { |dst| HashUtils.dig(dst, :app, :guid) }.compact

      @apps_hash = AppModel.where(guid: desired_app_guids).each_with_object({}) { |app, apps_hsh| apps_hsh[app.guid] = app }
      validate_app_guids!(@apps_hash, desired_app_guids)
      validate_app_spaces!(@apps_hash, route)
      @apps_hash
    end
  end

  def destroy_destination
    route = Route.find(guid: hashed_params[:guid])
    route_not_found! unless route

    route_not_found! unless permission_queryer.can_read_route?(route.space_id)
    unauthorized! unless permission_queryer.can_manage_apps_in_active_space?(route.space_id)
    suspended! unless permission_queryer.is_space_active?(route.space_id)

    destination = RouteMappingModel.find(guid: hashed_params[:destination_guid])
    unprocessable_destination! unless destination

    UpdateRouteDestinations.delete(destination, route, user_audit_info)

    head :no_content
  rescue UpdateRouteDestinations::Error => e
    unprocessable!(e.message)
  end

  def index_by_app
    message = RoutesListMessage.from_params(query_params.merge({ app_guids: hashed_params['guid'] }))
    invalid_param!(message.errors.full_messages) unless message.valid?

    app, space = AppFetcher.new.fetch(hashed_params['guid'])
    app_not_found! unless app && permission_queryer.can_read_from_space?(space.id, space.organization_id)

    dataset = if permission_queryer.can_read_globally?
                RouteFetcher.fetch(
                  message,
                  omniscient: true,
                  eager_loaded_associations: Presenters::V3::RoutePresenter.associated_resources
                )
              else
                RouteFetcher.fetch(
                  message,
                  readable_space_guids_dataset: permission_queryer.readable_space_guids_query,
                  eager_loaded_associations: Presenters::V3::RoutePresenter.associated_resources
                )
              end

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::RoutePresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: "/v3/apps/#{app.guid}/routes",
      message: message,
    )
  end

  private

  def route_not_found!
    resource_not_found!(:route)
  end

  def unprocessable_destination!
    unprocessable!('Unable to unmap route from destination. Ensure the route has a destination with this guid.')
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

  def unprocessable_protocol_host!
    unprocessable!('Hosts are not supported for TCP routes.')
  end

  def unprocessable_protocol_path!
    unprocessable!('Paths are not supported for TCP routes.')
  end

  def validate_app_guids!(apps_hash, desired_app_guids)
    existing_app_guids = apps_hash.keys

    not_existing_app_guids = desired_app_guids - existing_app_guids
    unprocessable!("App(s) with guid(s) \"#{not_existing_app_guids.join('", "')}\" do not exist.") unless not_existing_app_guids.empty?

    unless permission_queryer.can_read_globally?
      unauthorized_app_guids = desired_app_guids - permission_queryer.readable_app_guids
      unprocessable!("App(s) with guid(s) \"#{unauthorized_app_guids.join('", "')}\" you do not have access.") unless unauthorized_app_guids.empty?
    end
  end

  def validate_app_spaces!(apps_hash, route)
    if apps_hash.values.any? { |app| app.space != route.space && !route.shared_spaces.include?(app.space) }
      unprocessable!("Routes destinations must be in either the route's space or the route's shared spaces")
    end
  end

  def app_not_found!
    resource_not_found!(:app)
  end

  def routing_api_client
    @routing_api_client ||= CloudController::DependencyLocator.instance.routing_api_client
  end

  def can_read_space?(space)
    permission_queryer.can_read_from_space?(space.id, space.organization_id)
  end

  def can_write_space?(space)
    permission_queryer.can_write_to_active_space?(space.id) && permission_queryer.is_space_active?(space.id)
  end

  def check_spaces_exist_and_are_writeable!(route, request_guids, found_spaces)
    unreadable_spaces = found_spaces.reject { |s| can_read_space?(s) }
    unwriteable_spaces = found_spaces.reject { |s| can_write_space?(s) || unreadable_spaces.include?(s) }

    not_found_space_guids = request_guids - found_spaces.map(&:guid)
    unreadable_space_guids = not_found_space_guids + unreadable_spaces.map(&:guid)
    unwriteable_space_guids = unwriteable_spaces.map(&:guid)

    if unreadable_space_guids.any? || unwriteable_space_guids.any?
      unreadable_error = unreadable_error_message(route.uri, unreadable_space_guids)
      unwriteable_error = unwriteable_error_message(route.uri, unwriteable_space_guids)

      error_msg = [unreadable_error, unwriteable_error].map(&:presence).compact.join("\n")

      unprocessable!(error_msg)
    end
  end

  def unreadable_error_message(uri, unreadable_space_guids)
    if unreadable_space_guids.any?
      unreadable_guid_list = unreadable_space_guids.map { |g| "'#{g}'" }.join(', ')

      "Unable to share route #{uri} with spaces [#{unreadable_guid_list}]. Ensure the spaces exist and that you have access to them."
    end
  end

  def unwriteable_error_message(uri, unwriteable_space_guids)
    if unwriteable_space_guids.any?
      unwriteable_guid_list = unwriteable_space_guids.map { |s| "'#{s}'" }.join(', ')

      "Unable to share route #{uri} with spaces [#{unwriteable_guid_list}]. "\
      'Write permission is required in order to share a route with a space and the containing organization must not be suspended.'
    end
  end

  def check_if_space_is_accessible(space)
    if space.nil? || !can_read_space?(space)
      return 'Ensure the space exists and that you have access to it.'
    elsif !permission_queryer.can_manage_apps_in_active_space?(space.id)
      return "You don't have write permission for the target space."
    elsif !permission_queryer.is_space_active?(space.id)
      return 'The target organization is suspended.'
    end

    nil
  end
end
