require 'presenters/system_environment/service_instance_presenter'

class ServiceBindingPresenter
  WHITELISTED_VOLUME_FIELDS = %w[container_dir mode device_type].freeze

  def initialize(service_binding, include_instance: false)
    @service_binding = service_binding
    @include_instance = include_instance
  end

  def to_hash
    present_service_binding(service_binding).tap do |presented|
      presented.reverse_merge!(ServiceInstancePresenter.new(service_instance).to_hash) if include_instance
    end
  end

  def self.censor_volume_mounts(volume_mounts)
    return [] unless volume_mounts.is_a?(Array)

    volume_mounts.map do |mount_info|
      mount_info.select { |k, _v| WHITELISTED_VOLUME_FIELDS.include?(k) }
    end
  end

  private

  attr_reader :service_binding, :include_instance

  def service_instance
    service_binding.service_instance
  end

  def present_service_binding(service_binding)
    {
      name: service_binding.name.presence || service_instance.name,
      instance_guid: service_instance.guid,
      instance_name: service_instance.name,
      binding_guid: service_binding.guid,
      binding_name: service_binding.name,
      credentials: service_binding.credentials,
      syslog_drain_url: service_binding.syslog_drain_url,
      volume_mounts: ServiceBindingPresenter.censor_volume_mounts(service_binding.volume_mounts)
    }
  end
end
