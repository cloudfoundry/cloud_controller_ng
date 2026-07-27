require 'messages/route_policy_create_message'
require 'messages/route_policy_update_message'
require 'messages/route_policies_list_message'
require 'messages/route_policy_show_message'
require 'presenters/v3/route_policy_presenter'
require 'decorators/include_route_policy_source_decorator'
require 'decorators/include_route_policy_route_decorator'
require 'actions/route_policy_create'
require 'actions/route_policy_update'
require 'actions/route_policy_destroy'
require 'fetchers/label_selector_query_generator'

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

    route_policy = find_route_policy_with_route_and_space(hashed_params[:guid])
    resource_not_found!(:route_policy) unless route_policy

    route = route_policy.route
    resource_not_found!(:route_policy) unless route && permission_queryer.can_read_route_policy_from_space?(route.space.id, route.space.organization_id)

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

    route_policy = VCAP::CloudController::RoutePolicyCreate.new(user_audit_info).create(route: route, message: message)

    render status: :created, json: Presenters::V3::RoutePolicyPresenter.new(route_policy)
  rescue VCAP::CloudController::RoutePolicyCreate::Error => e
    unprocessable!(e.message)
  end

  def update
    route_policy = find_route_policy_with_route_and_space(hashed_params[:guid])
    resource_not_found!(:route_policy) unless route_policy

    find_and_authorize_route_for_policy(route_policy)

    message = RoutePolicyUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    route_policy = VCAP::CloudController::RoutePolicyUpdate.new(user_audit_info).update(route_policy, message)

    render status: :ok, json: Presenters::V3::RoutePolicyPresenter.new(route_policy)
  end

  def destroy
    route_policy = find_route_policy_with_route_and_space(hashed_params[:guid])
    resource_not_found!(:route_policy) unless route_policy

    find_and_authorize_route_for_policy(route_policy)

    VCAP::CloudController::RoutePolicyDestroy.new(user_audit_info).delete(route_policy)

    head :no_content
  end

  private

  def find_route_policy_with_route_and_space(guid)
    VCAP::CloudController::RoutePolicy.eager_graph(route: :space).where(Sequel[:route_policies][:guid] => guid).all[0]
  end

  def find_and_authorize_route(route_guid)
    route = VCAP::CloudController::Route.find(guid: route_guid)
    resource_not_found!(:route) unless route && permission_queryer.can_read_from_space?(route.space.id, route.space.organization_id)
    unauthorized! unless permission_queryer.can_write_to_active_space?(route.space.id)
    require_writable_space!(route.space)
    route
  end

  def find_and_authorize_route_for_policy(route_policy)
    route = route_policy.route
    resource_not_found!(:route_policy) unless route && permission_queryer.can_read_route_policy_from_space?(route.space.id, route.space.organization_id)
    unauthorized! unless permission_queryer.can_write_to_active_space?(route.space.id)
    require_writable_space!(route.space)
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
      readable_space_ids = permission_queryer.readable_route_policies_spaces_query.select(:id)
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

    if message.requested?(:sources)
      conditions = message.sources.map do |src|
        if src == 'cf:any'
          Sequel.&(source_type: 'any', source_guid: '')
        else
          m = src.match(/\Acf:(app|space|org):([0-9a-f-]+)\z/)
          Sequel.&(source_type: m[1], source_guid: m[2])
        end
      end
      dataset = dataset.where(Sequel.|(*conditions))
    end

    dataset = dataset.where(source_guid: message.source_guids) if message.requested?(:source_guids)

    if message.requested?(:label_selector)
      dataset = VCAP::CloudController::LabelSelectorQueryGenerator.add_selector_queries(
        label_klass: VCAP::CloudController::RoutePolicyLabelModel,
        resource_dataset: dataset,
        requirements: message.requirements,
        resource_klass: VCAP::CloudController::RoutePolicy
      )
    end

    dataset
  end
end
