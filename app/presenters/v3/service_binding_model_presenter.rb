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
        data: present_service_binding(service_binding),
        created_at: service_binding.created_at,
        updated_at: service_binding.updated_at,
        links: build_links
      }
    end

    private

    def present_service_binding(service_binding)
      ServiceBindingPresenter.new(service_binding)
    end

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
  end
end
