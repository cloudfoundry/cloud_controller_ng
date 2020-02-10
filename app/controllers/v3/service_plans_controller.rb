require 'presenters/v3/service_plan_presenter'
require 'fetchers/service_plan_list_fetcher'
require 'fetchers/service_plan_fetcher'
require 'controllers/v3/mixins/service_permissions'
require 'messages/service_plans_list_message'
require 'actions/service_plan_delete'
require 'messages/metadata_update_message'
require 'actions/transactional_metadata_update'

class ServicePlansController < ApplicationController
  include ServicePermissions

  def show
    not_authenticated! if user_cannot_see_marketplace?

    service_plan = ServicePlanFetcher.fetch(hashed_params[:guid])
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

  def update
    service_plan = ServicePlanFetcher.fetch(hashed_params[:guid])
    service_plan_not_found! if service_plan.nil?
    cannot_write!(service_plan) unless current_user_can_write?(service_plan)

    message = MetadataUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    updated_service_plan = TransactionalMetadataUpdate.update(service_plan, message)
    presenter = Presenters::V3::ServicePlanPresenter.new(updated_service_plan)

    render :ok, json: presenter.to_json
  end

  def destroy
    service_plan = ServicePlanFetcher.fetch(hashed_params[:guid])
    service_plan_not_found! if service_plan.nil?
    cannot_write!(service_plan) unless current_user_can_write?(service_plan)

    service_event_repository = VCAP::CloudController::Repositories::ServiceEventRepository.new(user_audit_info)

    ServicePlanDelete.new.delete(service_plan)
    service_event_repository.record_service_plan_event(:delete, service_plan)

    head :no_content
  rescue ServicePlanDelete::AssociationNotEmptyError => e
    unprocessable!(e.message)
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

  def cannot_write!(service_plan)
    unauthorized! if visible_to_current_user?(plan: service_plan)
    service_plan_not_found!
  end
end
