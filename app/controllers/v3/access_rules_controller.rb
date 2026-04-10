require 'messages/access_rule_create_message'
require 'messages/access_rule_update_message'
require 'messages/access_rules_list_message'
require 'presenters/v3/access_rule_presenter'
require 'decorators/include_access_rule_selector_resource_decorator'
require 'decorators/include_access_rule_route_decorator'

class AccessRulesController < ApplicationController
  def index
    message = AccessRulesListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    dataset = build_dataset(message)

    decorators = []
    decorators << IncludeAccessRuleSelectorResourceDecorator if IncludeAccessRuleSelectorResourceDecorator.match?(message.include)
    decorators << IncludeAccessRuleRouteDecorator if IncludeAccessRuleRouteDecorator.match?(message.include)

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::AccessRulePresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: '/v3/access_rules',
      message: message,
      decorators: decorators
    )
  end

  def show
    access_rule = VCAP::CloudController::RouteAccessRule.find(guid: hashed_params[:guid])
    resource_not_found!(:access_rule) unless access_rule

    route = access_rule.route
    resource_not_found!(:access_rule) unless route && permission_queryer.can_read_from_space?(route.space.id, route.space.organization_id)

    render status: :ok, json: Presenters::V3::AccessRulePresenter.new(access_rule)
  end

  def create
    message = AccessRuleCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    route = VCAP::CloudController::Route.find(guid: message.route_guid)
    resource_not_found!(:route) unless route && permission_queryer.can_read_from_space?(route.space.id, route.space.organization_id)
    unauthorized! unless permission_queryer.can_write_to_active_space?(route.space.id)
    suspended! unless permission_queryer.is_space_active?(route.space.id)

    unprocessable!("Cannot create access rules for route '#{route.guid}': the route's domain does not have enforce_access_rules enabled.") unless route.domain.enforce_access_rules

    # Enforce cf:any exclusivity: if route already has a cf:any rule, reject new rules;
    # if new rule is cf:any, reject if route already has any rules.
    existing_selectors = route.access_rules.map(&:selector)
    unprocessable!("Cannot add 'cf:any' selector when other access rules already exist for this route.") if message.selector == 'cf:any' && existing_selectors.any?
    unprocessable!("Cannot add selector '#{message.selector}': route already has a 'cf:any' rule.") if existing_selectors.include?('cf:any') && message.selector != 'cf:any'

    # Uniqueness: name and selector must be unique per route
    unprocessable!("An access rule with name '#{message.name}' already exists for this route.") if route.access_rules.any? { |r| r.name == message.name }
    unprocessable!("An access rule with selector '#{message.selector}' already exists for this route.") if existing_selectors.include?(message.selector)

    access_rule = VCAP::CloudController::RouteAccessRule.new(
      guid: SecureRandom.uuid,
      name: message.name,
      selector: message.selector,
      route_id: route.id,
      created_at: Time.now.utc,
      updated_at: Time.now.utc
    )
    access_rule.save

    render status: :created, json: Presenters::V3::AccessRulePresenter.new(access_rule)
  end

  def update
    access_rule = VCAP::CloudController::RouteAccessRule.find(guid: hashed_params[:guid])
    resource_not_found!(:access_rule) unless access_rule

    route = access_rule.route
    resource_not_found!(:access_rule) unless route && permission_queryer.can_read_from_space?(route.space.id, route.space.organization_id)
    unauthorized! unless permission_queryer.can_write_to_active_space?(route.space.id)
    suspended! unless permission_queryer.is_space_active?(route.space.id)

    message = AccessRuleUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    VCAP::CloudController::MetadataUpdate.update(access_rule, message)

    render status: :ok, json: Presenters::V3::AccessRulePresenter.new(access_rule.reload)
  end

  def destroy
    access_rule = VCAP::CloudController::RouteAccessRule.find(guid: hashed_params[:guid])
    resource_not_found!(:access_rule) unless access_rule

    route = access_rule.route
    resource_not_found!(:access_rule) unless route && permission_queryer.can_read_from_space?(route.space.id, route.space.organization_id)
    unauthorized! unless permission_queryer.can_write_to_active_space?(route.space.id)
    suspended! unless permission_queryer.is_space_active?(route.space.id)

    access_rule.destroy
    head :no_content
  end

  private

  def build_dataset(message)
    dataset = VCAP::CloudController::RouteAccessRule.dataset

    if permission_queryer.can_read_globally?
      readable_route_ids = VCAP::CloudController::Route.select(:id)
    else
      readable_space_ids = permission_queryer.readable_space_scoped_spaces_query.select(:id)
      readable_route_ids = VCAP::CloudController::Route.where(space_id: readable_space_ids).select(:id)
    end

    dataset = dataset.where(route_id: readable_route_ids)

    if message.requested?(:route_guids)
      dataset = dataset.
                join(:routes, id: :route_id).
                where(routes__guid: message.route_guids).
                select_all(:route_access_rules)
    end

    if message.requested?(:space_guids)
      dataset = dataset.
                join(:routes, id: :route_id).
                where(routes__space_id: VCAP::CloudController::Space.where(guid: message.space_guids).select(:id)).
                select_all(:route_access_rules)
    end

    dataset = dataset.where(name: message.names) if message.requested?(:names)
    dataset = dataset.where(selector: message.selectors) if message.requested?(:selectors)

    dataset
  end
end
