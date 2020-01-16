require 'fetchers/service_offering_fetcher'
require 'fetchers/service_offering_list_fetcher'
require 'fetchers/service_plan_visibility_fetcher'
require 'presenters/v3/service_offering_presenter'
require 'messages/service_offerings_list_message'
require 'actions/service_offering_delete'

class ServiceOfferingsController < ApplicationController
  def index
    not_authenticated! if user_cannot_see_marketplace?

    message = ServiceOfferingsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    dataset = if !current_user
                ServiceOfferingListFetcher.new.fetch_public(message)
              elsif permission_queryer.can_read_globally?
                ServiceOfferingListFetcher.new.fetch(message)
              else
                ServiceOfferingListFetcher.new.fetch_visible(
                  message,
                  permission_queryer.readable_org_guids,
                  permission_queryer.readable_space_scoped_space_guids,
                )
              end

    presenter = Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::ServiceOfferingPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, VCAP::CloudController::ListMessage.from_params(query_params, []).try(:pagination_options)),
      path: '/v3/service_offerings',
    )

    render status: :ok, json: presenter.to_json
  end

  def show
    not_authenticated! if user_cannot_see_marketplace?

    service_offering, space, public = ServiceOfferingFetcher.fetch(hashed_params[:guid])
    service_offering_not_found! if service_offering.nil?

    if permission_queryer.can_read_globally? || public || visible_space_scoped?(space) || visible_in_readable_orgs?(service_offering)
      presenter = Presenters::V3::ServiceOfferingPresenter.new(service_offering)
      render status: :ok, json: presenter.to_json
    else
      service_offering_not_found!
    end
  end

  def destroy
    service_offering, _space, public = ServiceOfferingFetcher.fetch(hashed_params[:guid])
    service_offering_not_found! if service_offering.nil?

    if (public || visible_in_readable_orgs?(service_offering)) && !permission_queryer.can_write_globally?
      unauthorized!
    end
    service_offering_not_found! unless permission_queryer.can_write_globally?

    ServiceOfferingDelete.new.delete(service_offering)
    head :no_content
  rescue ServiceOfferingDelete::AssociationNotEmptyError => e
    unprocessable!(e.message)
  end

  private

  def enforce_authentication?
    %w(show index).include?(action_name) ? false : super
  end

  def enforce_read_scope?
    %w(show index).include?(action_name) ? false : super
  end

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

  def user_cannot_see_marketplace?
    !current_user && VCAP::CloudController::FeatureFlag.enabled?(:hide_marketplace_from_unauthenticated_users)
  end
end
