class ServiceCredentialBindingsController < ApplicationController
  before_action :ensure_service_key_exists!
  before_action :ensure_user_has_access!

  def show
    render status: :ok, json: hashed_params.slice(:guid)
  end

  private

  def ensure_service_key_exists!
    service_key_not_found! unless service_key_exists?
  end

  def ensure_user_has_access!
    service_key_not_found! unless allowed_to_access_space?
  end

  def service_key_not_found!
    resource_not_found!(:service_credential_binding)
  end

  def service_key
    @service_key ||= ServiceKey.first(guid: hashed_params[:guid])
  end

  def service_key_exists?
    !!service_key
  end

  def allowed_to_access_space?
    space = service_key.service_instance.space

    permission_queryer.can_read_from_space?(space.guid, space.organization_guid)
  end
end
