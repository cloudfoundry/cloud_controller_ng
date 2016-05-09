module VCAP::CloudController
  class ServiceBindingModelPresenter
    attr_reader :service_binding

    def initialize(service_binding)
      @service_binding = service_binding
    end

    def to_hash
      {
        guid: service_binding.guid,
        type: service_binding.type,
        data: {
          credentials: service_binding.credentials,
          syslog_drain_url: service_binding.syslog_drain_url,
          volume_mounts: censor_volume_mounts(service_binding.volume_mounts),
        },
        created_at: service_binding.created_at,
        updated_at: service_binding.updated_at,
        links: build_links
      }
    end

    private

    def build_links
      {
        self:   {
          href: "/v3/service_bindings/#{service_binding.guid}"
        },
        service_instance: {
          href: "/v2/service_instances/#{service_binding.service_instance.guid}"
        },
        app: {
          href: "/v3/apps/#{service_binding.app.guid}"
        },
      }
    end

    def censor_volume_mounts(volume_mounts)
      return [] unless volume_mounts.is_a?(Array)

      volume_mounts.each do |mount_info|
        mount_info.delete('private')
        mount_info
      end

      volume_mounts
    end
  end
end
