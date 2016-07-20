require 'queries/service_binding_create_fetcher'
require 'queries/service_binding_list_fetcher'
require 'presenters/v3/service_binding_model_presenter'
require 'messages/service_binding_create_message'
require 'messages/service_bindings_list_message'
require 'actions/service_binding_create'
require 'actions/service_binding_delete'
require 'controllers/v3/mixins/sub_resource'

class ServiceBindingsController < ApplicationController
  include SubResource

  def create
    message = ServiceBindingCreateMessage.create_from_http_request(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    app_guid = params[:body]['relationships']['app']['guid']
    service_instance_guid = params[:body]['relationships']['service_instance']['guid']

    app, service_instance = ServiceBindingCreateFetcher.new.fetch(app_guid, service_instance_guid)
    app_not_found! unless app
    service_instance_not_found! unless service_instance
    unauthorized! unless can_write?(app.space.guid)

    begin
      service_binding = ServiceBindingCreate.new(current_user.guid, current_user_email).create(app, service_instance, message, volume_services_enabled?)
      render status: :created, json: Presenters::V3::ServiceBindingModelPresenter.new(service_binding)
    rescue ServiceBindingCreate::ServiceInstanceNotBindable
      raise CloudController::Errors::ApiError.new_from_details('UnbindableService')
    rescue ServiceBindingCreate::InvalidServiceBinding
      raise CloudController::Errors::ApiError.new_from_details('ServiceBindingAppServiceTaken', "#{app.guid} #{service_instance.guid}")
    rescue ServiceBindingCreate::VolumeMountServiceDisabled
      raise CloudController::Errors::ApiError.new_from_details('VolumeMountServiceDisabled')
    end
  end

  def show
    service_binding = VCAP::CloudController::ServiceBindingModel.find(guid: params[:guid])

    service_binding_not_found! unless service_binding && can_read?(service_binding.space.guid, service_binding.space.organization.guid)
    render status: :ok, json: Presenters::V3::ServiceBindingModelPresenter.new(service_binding, show_secrets: can_see_secrets?(service_binding.space))
  end

  def index
    message = ServiceBindingsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    dataset = if roles.admin? || roles.admin_read_only?
                ServiceBindingListFetcher.new(message).fetch_all
              else
                ServiceBindingListFetcher.new(message).fetch(space_guids: readable_space_guids)
              end

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(dataset, '/v3/service_bindings', message)
  end

  def destroy
    service_binding = VCAP::CloudController::ServiceBindingModel.find(guid: params[:guid])

    service_binding_not_found! unless service_binding && can_read?(service_binding.space.guid, service_binding.space.organization.guid)
    unauthorized! unless can_write?(service_binding.space.guid)

    ServiceBindingModelDelete.new(current_user.guid, current_user_email).synchronous_delete(service_binding)

    head :no_content

  rescue ServiceBindingModelDelete::FailedToDelete => e
    unprocessable!(e.message)
  end

  private

  def service_instance_not_found!
    resource_not_found!(:service_instance)
  end

  def service_binding_not_found!
    resource_not_found!(:service_binding)
  end

  def volume_services_enabled?
    configuration[:volume_services_enabled]
  end
end
