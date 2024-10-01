require 'presenters/system_environment/service_instance_presenter'
require 'presenters/system_environment/service_binding_presenter'

class SystemEnvPresenter
  def initialize(app_or_process)
    @file_based_service_bindings_enabled = app_or_process.file_based_service_bindings_enabled
    @service_bindings = app_or_process.service_bindings
  end

  def system_env
    return { SERVICE_BINDING_ROOT: '/etc/cf-service-bindings' } if @file_based_service_bindings_enabled

    { VCAP_SERVICES: service_binding_env_variables }
  end

  private

  def service_binding_env_variables
    services_hash = {}
    @service_bindings.select(&:create_succeeded?).each do |service_binding|
      service_name = service_binding_label(service_binding)
      services_hash[service_name.to_sym] ||= []
      services_hash[service_name.to_sym] << service_binding_env_values(service_binding)
    end
    services_hash
  end

  def service_binding_env_values(service_binding)
    ServiceBindingPresenter.new(service_binding, include_instance: true)
  end

  def service_binding_label(service_binding)
    ServiceInstancePresenter.new(service_binding.service_instance).to_hash[:label]
  end
end
