require 'fetchers/service_credential_binding_fetcher'

class ServiceCredentialBindingsController < ApplicationController
  before_action :ensure_service_credential_binding_exists!
  before_action :ensure_user_has_access!

  def show
    render status: :ok, json: serialized
  end

  private

  def serialized
    {
      guid: service_credential_binding.guid,
      type: service_credential_binding.type
    }
  end

  def ensure_service_credential_binding_exists!
    not_found! unless service_credential_binding_exists?
  end

  def ensure_user_has_access!
    not_found! unless allowed_to_access_space?
  end

  def not_found!
    resource_not_found!(:service_credential_binding)
  end

  def service_credential_binding
    @service_credential_binding ||= fetcher.fetch(hashed_params[:guid])
  end

  def fetcher
    @fetcher ||= VCAP::CloudController::ServiceCredentialBindingFetcher.new
  end

  def service_credential_binding_exists?
    !!service_credential_binding
  end

  def allowed_to_access_space?
    space = service_credential_binding.space

    permission_queryer.can_read_from_space?(space.guid, space.organization_guid)
  end
end
