require 'fetchers/service_offering_fetcher'
require 'fetchers/service_offering_list_fetcher'
require 'fetchers/service_plan_visibility_fetcher'
require 'presenters/v3/service_offering_presenter'
require 'messages/service_offerings_list_message'
require 'messages/service_offering_update_message'
require 'messages/purge_message'
require 'actions/service_offering_delete'
require 'actions/service_offering_update'

class ServiceOfferingsController < ApplicationController
  include ServicePermissions

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
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: '/v3/service_offerings',
    )

    render status: :ok, json: presenter.to_json
  end

  def show
    not_authenticated! if user_cannot_see_marketplace?

    service_offering = ServiceOfferingFetcher.fetch(hashed_params[:guid])
    service_offering_not_found! if service_offering.nil?
    service_offering_not_found! unless visible_to_current_user?(service: service_offering)

    presenter = Presenters::V3::ServiceOfferingPresenter.new(service_offering)
    render status: :ok, json: presenter.to_json
  end

  def update
    service_offering = ServiceOfferingFetcher.fetch(hashed_params[:guid])
    service_offering_not_found! if service_offering.nil?

    cannot_write!(service_offering) unless current_user_can_write?(service_offering)

    message = ServiceOfferingUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    updated_service_offering = ServiceOfferingUpdate.update(service_offering, message)
    presenter = Presenters::V3::ServiceOfferingPresenter.new(updated_service_offering)

    render :ok, json: presenter.to_json
  end

  def destroy
    message = PurgeMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    service_offering = ServiceOfferingFetcher.fetch(hashed_params[:guid])
    service_offering_not_found! if service_offering.nil?

    cannot_write!(service_offering) unless current_user_can_write?(service_offering)

    service_event_repository = VCAP::CloudController::Repositories::ServiceEventRepository.new(user_audit_info)

    if message.purge?
      service_offering.purge(service_event_repository)
      service_event_repository.record_service_purge_event(service_offering)
    else
      ServiceOfferingDelete.new.delete(service_offering)
      service_event_repository.record_service_event(:delete, service_offering)
    end

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

  def service_offering_not_found!
    resource_not_found!(:service_offering)
  end

  def writable_space_scoped?(space)
    space && space.has_developer?(current_user)
  end

  def current_user_can_write?(service_offering)
    permission_queryer.can_write_globally? || writable_space_scoped?(service_offering.service_broker.space)
  end

  def cannot_write!(service_offering)
    unauthorized! if visible_to_current_user?(service: service_offering)
    service_offering_not_found!
  end
end
