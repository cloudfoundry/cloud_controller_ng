require 'presenters/v3/service_plan_presenter'
require 'fetchers/service_plan_list_fetcher'

class ServicePlansController < ApplicationController
  def show
    not_authenticated! if user_cannot_see_marketplace?

    service_plan = ServicePlan.where(public: true, guid: hashed_params[:guid]).first
    service_plan_not_found! if service_plan.nil?

    presenter = Presenters::V3::ServicePlanPresenter.new(service_plan)
    render status: :ok, json: presenter.to_json
  end

  def index
    not_authenticated! if user_cannot_see_marketplace?

    dataset = ServicePlanListFetcher.new.fetch_public

    presenter = Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::ServicePlanPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, VCAP::CloudController::ListMessage.from_params(query_params, []).try(:pagination_options)),
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

  def not_authenticated!
    raise CloudController::Errors::NotAuthenticated
  end

  def user_cannot_see_marketplace?
    !current_user && VCAP::CloudController::FeatureFlag.enabled?(:hide_marketplace_from_unauthenticated_users)
  end
end
