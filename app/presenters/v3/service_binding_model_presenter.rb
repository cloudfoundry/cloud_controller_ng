module VCAP::CloudController
  class ServiceBindingModelPresenter
    def present_json(service_binding)
      service_binding_hash = {
        guid: service_binding.guid,
        type: service_binding.type,
        data: {
          credentials: service_binding.credentials,
          syslog_drain_url: service_binding.syslog_drain_url,
        },
        created_at: service_binding.created_at,
        updated_at: service_binding.updated_at,
        links: build_links(service_binding)
      }
      MultiJson.dump(service_binding_hash, pretty: true)
    end

    private

    def build_links(service_binding)
      {
        self:   {
          href: "/v3/service_bindings/#{service_binding.guid}"
        },
        service_instance: {
          href: "/v2/service_instances/#{service_binding.service_instance.guid}"
        },
        app: {
          href: "/v3/app/#{service_binding.app.guid}"
        },
      }
    end
  end
end
