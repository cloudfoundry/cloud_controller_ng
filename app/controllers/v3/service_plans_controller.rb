require 'presenters/v3/service_plan_presenter'
require 'fetchers/service_plan_list_fetcher'
require 'fetchers/service_plan_fetcher'
require 'controllers/v3/mixins/service_permissions'
require 'messages/service_plans_list_message'
require 'messages/service_plans_show_message'
require 'actions/service_plan_delete'
require 'messages/metadata_update_message'
require 'actions/transactional_metadata_update'
require 'decorators/include_service_plan_space_organization_decorator'
require 'decorators/include_service_plan_service_offering_decorator'
require 'decorators/field_service_plan_service_broker_decorator'

class ServicePlansController < ApplicationController
  include ServicePermissions

  def show
    not_authenticated! if user_cannot_see_marketplace?

    message = ServicePlansShowMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    service_plan = ServicePlanFetcher.fetch(hashed_params[:guid])
    service_plan_not_found! if service_plan.nil?
    service_plan_not_found! unless visible_to_current_user?(plan: service_plan)

    decorators = []
    decorators << IncludeServicePlanSpaceOrganizationDecorator if IncludeServicePlanSpaceOrganizationDecorator.match?(message.include)
    decorators << IncludeServicePlanServiceOfferingDecorator if IncludeServicePlanServiceOfferingDecorator.match?(message.include)
    decorators << FieldServicePlanServiceBrokerDecorator.new(message.fields) if FieldServicePlanServiceBrokerDecorator.match?(message.fields)

    presenter = Presenters::V3::ServicePlanPresenter.new(service_plan, decorators: decorators)
    render status: :ok, json: presenter.to_json
  end

  def index
    not_authenticated! if user_cannot_see_marketplace?

    message = ServicePlansListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    dataset = if !current_user
                ServicePlanListFetcher.fetch(
                  message,
                  eager_loaded_associations: Presenters::V3::ServicePlanPresenter.associated_resources
                )
              elsif permission_queryer.can_read_globally?
                ServicePlanListFetcher.fetch(
                  message,
                  eager_loaded_associations: Presenters::V3::ServicePlanPresenter.associated_resources,
                  omniscient: true
                )
              else
                ServicePlanListFetcher.fetch(
                  message,
                  eager_loaded_associations: Presenters::V3::ServicePlanPresenter.associated_resources,
                  readable_orgs_query: permission_queryer.readable_orgs_query,
                  readable_spaces_query: permission_queryer.readable_space_scoped_spaces_query
                )
              end

    decorators = []
    decorators << IncludeServicePlanSpaceOrganizationDecorator if IncludeServicePlanSpaceOrganizationDecorator.match?(message.include)
    decorators << IncludeServicePlanServiceOfferingDecorator if IncludeServicePlanServiceOfferingDecorator.match?(message.include)
    decorators << FieldServicePlanServiceBrokerDecorator.new(message.fields) if FieldServicePlanServiceBrokerDecorator.match?(message.fields)

    presenter = Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::ServicePlanPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      message: message,
      path: '/v3/service_plans',
      decorators: decorators
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
    service_event_repository.record_service_plan_delete_event(service_plan)

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
