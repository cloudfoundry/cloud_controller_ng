require 'queries/service_binding_create_fetcher'
require 'presenters/v3/service_binding_model_presenter'
require 'messages/service_binding_create_message'
require 'messages/service_bindings_list_message'
require 'actions/service_binding_create'

class ServiceBindingsController < ApplicationController
  def create
    message = ServiceBindingCreateMessage.create_from_http_request(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    app_guid = params[:body]['relationships']['app']['guid']
    service_instance_guid = params[:body]['relationships']['service_instance']['guid']

    app, service_instance = ServiceBindingCreateFetcher.new.fetch(app_guid, service_instance_guid)
    app_not_found! unless app
    service_instance_not_found! unless service_instance
    unauthorized! unless can_create?(app.space.guid)

    begin
      service_binding = ServiceBindingCreate.new.create(app, service_instance, message)
      render status: :created, json: ServiceBindingModelPresenter.new.present_json(service_binding)
    rescue ServiceBindingCreate::ServiceInstanceNotBindable
      raise VCAP::Errors::ApiError.new_from_details('UnbindableService')
    rescue ServiceBindingCreate::InvalidServiceBinding
      raise VCAP::Errors::ApiError.new_from_details('ServiceBindingAppServiceTaken', "#{app.guid} #{service_instance.guid}")
    end
  end

  private

  def membership
    @membership ||= Membership.new(current_user)
  end

  def can_create?(space_guid)
    roles.admin? || membership.has_any_roles?([VCAP::CloudController::Membership::SPACE_DEVELOPER], space_guid)
  end

  def app_not_found!
    raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'App not found')
  end

  def service_instance_not_found!
    raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'Service instance not found')
  end
end
