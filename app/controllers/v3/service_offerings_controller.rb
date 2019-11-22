require 'fetchers/service_offerings_fetcher'
require 'fetchers/service_plan_visibility_fetcher'
require 'presenters/v3/service_offering_presenter'

class ServiceOfferingsController < ApplicationController
  def show
    guid = hashed_params[:guid]

    not_authenticated! if !current_user && VCAP::CloudController::FeatureFlag.enabled?(:hide_marketplace_from_unauthenticated_users)

    offering, space, public = ServiceOfferingsFetcher.fetch(guid)
    service_offering_not_found! if offering.nil?

    if permission_queryer.can_read_globally? || public || visible_space_scoped?(space) || visible_in_readable_orgs?(offering)
      presenter = Presenters::V3::ServiceOfferingPresenter.new(offering)
      render status: :ok, json: presenter.to_json
    else
      service_offering_not_found!
    end
  end

  def enforce_authentication?
    action_name == 'show' ? false : super
  end

  def enforce_read_scope?
    action_name == 'show' ? false : super
  end

  private

  def visible_in_readable_orgs?(offering)
    return false if !current_user

    ServicePlanVisibilityFetcher.service_plans_visible_in_orgs?(offering.service_plans.map(&:guid), permission_queryer.readable_org_guids)
  end

  def visible_space_scoped?(space)
    return false if !current_user
    return false if !space

    space.has_member?(current_user)
  end

  def service_offering_not_found!
    resource_not_found!(:service_offering)
  end

  def not_authenticated!
    raise CloudController::Errors::NotAuthenticated
  end
end
