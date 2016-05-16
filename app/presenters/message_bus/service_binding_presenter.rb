require 'presenters/message_bus/service_instance_presenter'
require 'presenters/v3/mixins/redactor'

class ServiceBindingPresenter
  include CloudController::Redactor

  def initialize(service_binding, show_secrets: true, include_instance: false)
    @service_binding = service_binding
    @include_instance = include_instance
    @show_secrets = show_secrets
  end

  def to_hash
    present_service_binding(@service_binding).tap do |presented|
      presented.merge!(ServiceInstancePresenter.new(@service_binding.service_instance).to_hash) if @include_instance
    end
  end

  def self.censor_volume_mounts(volume_mounts)
    return [] unless volume_mounts.is_a?(Array)

    volume_mounts.map do |mount_info|
      mount_info.reject { |k, _v| k == 'private' }
    end
  end

  private

  def present_service_binding(service_binding)
    {
      credentials: redact_hash(service_binding.credentials, @show_secrets),
      syslog_drain_url: service_binding.syslog_drain_url,
      volume_mounts: ServiceBindingPresenter.censor_volume_mounts(service_binding.volume_mounts)
    }
  end
end
