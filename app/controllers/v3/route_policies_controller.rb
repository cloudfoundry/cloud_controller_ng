require 'messages/route_policy_create_message'
require 'messages/route_policy_update_message'
require 'messages/route_policies_list_message'
require 'messages/route_policy_show_message'
require 'presenters/v3/route_policy_presenter'
require 'decorators/include_route_policy_source_decorator'
require 'decorators/include_route_policy_route_decorator'
require 'actions/route_policy_create'

class RoutePoliciesController < ApplicationController
  def index
    message = RoutePoliciesListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    dataset = build_dataset(message)

    decorators = []
    decorators << IncludeRoutePolicySourceDecorator if IncludeRoutePolicySourceDecorator.match?(message.include)
    decorators << IncludeRoutePolicyRouteDecorator if IncludeRoutePolicyRouteDecorator.match?(message.include)

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::RoutePolicyPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: '/v3/route_policies',
      message: message,
      decorators: decorators
    )
  end

  def show
    message = RoutePolicyShowMessage.from_params(query_params)
    unprocessable!(message.errors.full_messages) unless message.valid?

    route_policy = VCAP::CloudController::RoutePolicy.find(guid: hashed_params[:guid])
    resource_not_found!(:route_policy) unless route_policy

    route = route_policy.route
    resource_not_found!(:route_policy) unless route && permission_queryer.can_read_from_space?(route.space.id, route.space.organization_id)

    decorators = []
    decorators << IncludeRoutePolicySourceDecorator if IncludeRoutePolicySourceDecorator.match?(message.include)
    decorators << IncludeRoutePolicyRouteDecorator if IncludeRoutePolicyRouteDecorator.match?(message.include)

    render status: :ok, json: Presenters::V3::RoutePolicyPresenter.new(route_policy, decorators: decorators)
  end

  def create
    message = RoutePolicyCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    route = find_and_authorize_route(message.route_guid)
    validate_route_domain(route)

    route_policy = VCAP::CloudController::RoutePolicyCreate.new.create(route: route, message: message)

    render status: :created, json: Presenters::V3::RoutePolicyPresenter.new(route_policy)
  rescue VCAP::CloudController::RoutePolicyCreate::Error => e
    unprocessable!(e.message)
  end

  def update
    route_policy = VCAP::CloudController::RoutePolicy.find(guid: hashed_params[:guid])
    resource_not_found!(:route_policy) unless route_policy

    find_and_authorize_route_for_policy(route_policy)

    message = RoutePolicyUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    VCAP::CloudController::MetadataUpdate.update(route_policy, message)

    render status: :ok, json: Presenters::V3::RoutePolicyPresenter.new(route_policy.reload)
  end

  def destroy
    route_policy = VCAP::CloudController::RoutePolicy.find(guid: hashed_params[:guid])
    resource_not_found!(:route_policy) unless route_policy

    find_and_authorize_route_for_policy(route_policy)

    route_policy.destroy
    head :no_content
  end

  private

  def find_and_authorize_route(route_guid)
    route = VCAP::CloudController::Route.find(guid: route_guid)
    resource_not_found!(:route) unless route && permission_queryer.can_read_from_space?(route.space.id, route.space.organization_id)
    unauthorized! unless permission_queryer.can_write_to_active_space?(route.space.id)
    suspended! unless permission_queryer.is_space_active?(route.space.id)
    route
  end

  def find_and_authorize_route_for_policy(route_policy)
    route = route_policy.route
    resource_not_found!(:route_policy) unless route && permission_queryer.can_read_from_space?(route.space.id, route.space.organization_id)
    unauthorized! unless permission_queryer.can_write_to_active_space?(route.space.id)
    suspended! unless permission_queryer.is_space_active?(route.space.id)
  end

  def validate_route_domain(route)
    if route.domain.internal?
      unprocessable!('Cannot create route policies for routes on internal domains. Internal routes use container-to-container networking and bypass GoRouter.')
    end
    return if route.domain.enforce_route_policies

    unprocessable!("Cannot create route policies for route '#{route.guid}': the route's domain does not have enforce_route_policies enabled.")
  end

  def build_dataset(message)
    dataset = VCAP::CloudController::RoutePolicy.dataset

    if permission_queryer.can_read_globally?
      readable_route_ids = VCAP::CloudController::Route.select(:id)
    else
      readable_space_ids = permission_queryer.readable_spaces_query.select(:id)
      readable_route_ids = VCAP::CloudController::Route.where(space_id: readable_space_ids).select(:id)
    end

    dataset = dataset.where(route_id: readable_route_ids)

    # Join routes at most once when either route_guids or space_guids is requested
    if message.requested?(:route_guids) || message.requested?(:space_guids)
      dataset = dataset.
                join(:routes, id: :route_id).
                select_all(:route_policies)

      dataset = dataset.where(Sequel[:routes][:guid] => message.route_guids) if message.requested?(:route_guids)

      dataset = dataset.where(Sequel[:routes][:space_id] => VCAP::CloudController::Space.where(guid: message.space_guids).select(:id)) if message.requested?(:space_guids)
    end

    dataset = dataset.where(guid: message.guids) if message.requested?(:guids)
    dataset = dataset.where(source: message.sources) if message.requested?(:sources)

    if message.requested?(:source_guids)
      # Text-match against source string for resource GUIDs
      # Handles cf:app:<guid>, cf:space:<guid>, cf:org:<guid>
      # Escape LIKE metacharacters (\, %, _) in user-provided values
      conditions = message.source_guids.map do |guid|
        escaped_guid = guid.gsub('\\', '\\\\').gsub('%', '\\%').gsub('_', '\\_')
        Sequel.like(:source, "%#{escaped_guid}%")
      end
      dataset = dataset.where(Sequel.|(*conditions))
    end

    dataset
  end
end
