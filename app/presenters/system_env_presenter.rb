class SystemEnvPresenter
  def initialize(service_bindings)
    @service_bindings = service_bindings
  end

  def system_env
    { VCAP_SERVICES: service_binding_env_variables(service_bindings) }
  end

  private

  attr_reader :service_bindings

  def service_binding_env_variables(service_bindings)
    services_hash = {}
    service_bindings.each do |service_binding|
      service_name = service_binding_label(service_binding)
      services_hash[service_name] ||= []
      services_hash[service_name] << service_binding_env_values(service_binding)
    end
    services_hash
  end

  def service_binding_env_values(service_binding)
    {
      credentials: service_binding.credentials,
      syslog_drain_url: service_binding.syslog_drain_url
    }.merge(ServiceInstancePresenter.new(service_binding.service_instance))
  end

  def service_binding_label(service_binding)
    ServiceInstancePresenter.new(service_binding.service_instance).to_hash[:label]
  end
end
