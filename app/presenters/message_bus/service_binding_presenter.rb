require 'presenters/message_bus/service_instance_presenter'

class ServiceBindingPresenter
  def initialize(service_binding)
    @service_binding = service_binding
  end

  def to_hash
    {
      credentials: @service_binding.credentials,
      options: @service_binding.binding_options || {},
      syslog_drain_url: @service_binding.syslog_drain_url
    }.merge(ServiceInstancePresenter.new(@service_binding.service_instance).to_hash)
  end
end
