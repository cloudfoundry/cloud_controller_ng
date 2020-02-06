require 'presenters/v3/service_plan_presenter'
require 'fetchers/service_plan_list_fetcher'
require 'controllers/v3/mixins/service_permissions'
require 'messages/service_plans_list_message'

class ServicePlansController < ApplicationController
  include ServicePermissions

  def show
    not_authenticated! if user_cannot_see_marketplace?

    service_plan = ServicePlan.where(guid: hashed_params[:guid]).first
    service_plan_not_found! if service_plan.nil?
    service_plan_not_found! unless visible_to_current_user?(plan: service_plan)

    presenter = Presenters::V3::ServicePlanPresenter.new(service_plan)
    render status: :ok, json: presenter.to_json
  end

  def index
    not_authenticated! if user_cannot_see_marketplace?

    message = ServicePlansListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    dataset = if !current_user
                ServicePlanListFetcher.new.fetch(message)
              elsif permission_queryer.can_read_globally?
                ServicePlanListFetcher.new.fetch(message, omniscient: true)
              else
                ServicePlanListFetcher.new.fetch(
                  message,
                  readable_org_guids: permission_queryer.readable_org_guids,
                  readable_space_guids: permission_queryer.readable_space_scoped_space_guids,
                )
              end

    presenter = Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::ServicePlanPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: '/v3/service_plans',
    )

    render status: :ok, json: presenter.to_json
  end

  private

  def enforce_authentication?
    %w(show index).include?(action_name) ? false : super
  end

  def enforce_read_scope?
    %w(show index).include?(action_name) ? false : super
  end

  def service_plan_not_found!
    resource_not_found!(:service_plan)
  end
end
