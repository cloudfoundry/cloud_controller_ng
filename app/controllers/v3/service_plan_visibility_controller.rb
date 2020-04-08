require 'presenters/v3/service_plan_visibility_presenter'
require 'fetchers/service_plan_visibility_fetcher'
require 'fetchers/service_plan_fetcher'
require 'controllers/v3/mixins/service_permissions'
require 'messages/service_plan_visibility_update_message'
require 'actions/v3/service_plan_visibility_update'
require 'actions/v3/service_plan_visibility_delete'

class ServicePlanVisibilityController < ApplicationController
  include ServicePermissions

  def show
    service_plan = ServicePlanFetcher.fetch(hashed_params[:guid])

    service_plan_not_found! unless service_plan.present? && visible_to_current_user?(plan: service_plan)

    visible_in_orgs = ServicePlanVisibilityFetcher.new(permission_queryer).fetch_orgs(
      service_plan_guids: [service_plan.guid]
    )
    presenter = Presenters::V3::ServicePlanVisibilityPresenter.new(service_plan, visible_in_orgs)
    render status: :ok, json: presenter.to_json
  end

  def update
    update_visibility
  end

  def apply
    update_visibility(append_organizations: true)
  end

  def destroy
    service_plan = ServicePlanFetcher.fetch(hashed_params[:guid])
    service_plan_not_found! unless service_plan.present? && visible_to_current_user?(plan: service_plan)
    unauthorized! unless current_user_can_write?(service_plan)
    unprocessable!('Cannot delete visibilities from non-org-restricted plans') unless service_plan.visibility_type == ServicePlanVisibilityTypes::ORGANIZATION

    org = Organization.where(guid: hashed_params[:org_guid]).first
    resource_not_found!(:organization) unless org.present?

    to_delete = ServicePlanVisibility.where(service_plan: service_plan, organization: org).first
    resource_not_found!(:service_plan_visibility) unless to_delete.present?

    ServicePlanVisibilityDelete.delete(to_delete)

    head :no_content
  end

  private

  def update_visibility(opts={})
    service_plan = ServicePlanFetcher.fetch(hashed_params[:guid])
    service_plan_not_found! unless service_plan.present? && visible_to_current_user?(plan: service_plan)
    unauthorized! unless current_user_can_write?(service_plan)

    message = ServicePlanVisibilityUpdateMessage.new(hashed_params[:body])
    bad_request!(message.errors.full_messages) unless message.valid?

    updated_service_plan = V3::ServicePlanVisibilityUpdate.new.update(service_plan, message, opts)

    visible_in_orgs = ServicePlanVisibilityFetcher.new(permission_queryer).fetch_orgs(
      service_plan_guids: [service_plan.guid]
    )
    presenter = Presenters::V3::ServicePlanVisibilityPresenter.new(updated_service_plan, visible_in_orgs)
    render status: :ok, json: presenter.to_json
  rescue V3::ServicePlanVisibilityUpdate::UnprocessableRequest => e
    unprocessable!(e.message)
  end

  def service_plan_not_found!
    resource_not_found!(:service_plan)
  end
end
