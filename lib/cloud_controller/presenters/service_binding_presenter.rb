class ServiceBindingPresenter

  def initialize(service_binding)
    @service_binding = service_binding
  end

  def service
    @service_binding.service_instance.service
  end

  def to_hash
    {
      label: [service.label, service.version].join('-'),
      name: @service_binding.service_instance.name,
      :credentials  => @service_binding.credentials,
      :options      => @service_binding.binding_options,
      :plan         => @service_binding.service_instance.service_plan.name,
      :plan_options => {},
    }
  end
end
