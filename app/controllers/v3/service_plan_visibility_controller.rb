require 'presenters/v3/service_plan_visibility_presenter'
require 'fetchers/service_plan_visibility_fetcher'
require 'fetchers/service_plan_fetcher'
require 'controllers/v3/mixins/service_permissions'

class ServicePlanVisibilityController < ApplicationController
  include ServicePermissions

  def show
    service_plan = ServicePlanFetcher.fetch(hashed_params[:guid])
    service_plan_not_found! if service_plan.nil?
    service_plan_not_found! unless visible_to_current_user?(plan: service_plan)

    visible_in_orgs = ServicePlanVisibilityFetcher.new(permission_queryer).fetch_orgs(
      service_plan_guids: [service_plan.guid]
    )
    presenter = Presenters::V3::ServicePlanVisibilityPresenter.new(service_plan, visible_in_orgs)
    render status: :ok, json: presenter.to_json
  end

  private

  def service_plan_not_found!
    resource_not_found!(:service_plan)
  end
end
