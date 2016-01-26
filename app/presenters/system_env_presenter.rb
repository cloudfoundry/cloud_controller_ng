class SystemEnvPresenter
  def initialize(service_bindings)
    @service_bindings = service_bindings
  end

  def system_env
    { 'VCAP_SERVICES' => service_binding_env_variables(service_bindings) }
  end

  private

  attr_reader :service_bindings

  def service_binding_env_variables(service_bindings)
    services_hash = {}
    service_bindings.each do |service_binding|
      service_name                = service_binding.service.label
      services_hash[service_name] ||= []
      services_hash[service_name] << service_binding_env_values(service_binding)
    end
    services_hash
  end

  def service_binding_env_values(service_binding)
    {
      'name'             => service_binding.service_instance.name,
      'label'            => service_binding.service.label,
      'tags'             => service_binding.service_instance.merged_tags,
      'plan'             => service_binding.service_instance.service_plan.name,
      'credentials'      => service_binding.credentials,
      'syslog_drain_url' => service_binding.syslog_drain_url
    }
  end
end
