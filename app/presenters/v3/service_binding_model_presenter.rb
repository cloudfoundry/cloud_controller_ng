module VCAP::CloudController
  class ServiceBindingModelPresenter
    def initialize(pagination_presenter=PaginationPresenter.new)
      @pagination_presenter = pagination_presenter
    end

    def present_json(service_binding)
      MultiJson.dump(service_binding_hash(service_binding), pretty: true)
    end

    def present_json_list(paginated_result, base_url)
      service_bindings = paginated_result.records

      service_binding_hashes = service_bindings.collect { |service_binding| service_binding_hash(service_binding) }

      paginated_response = {
        pagination: @pagination_presenter.present_pagination_hash(paginated_result, base_url),
        resources:  service_binding_hashes
      }

      MultiJson.dump(paginated_response, pretty: true)
    end

    private

    def service_binding_hash(service_binding)
      {
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
    end

    def build_links(service_binding)
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
