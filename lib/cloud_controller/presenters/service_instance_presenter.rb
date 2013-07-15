class ServiceInstancePresenter
  def initialize(service_instance)
    if service_instance.is_gateway_service
      @presenter = ManagedPresenter.new(service_instance)
    else
      @presenter = ProvidedPresenter.new(service_instance)
    end
  end

  def to_hash
    @presenter.to_hash
  end

  class ProvidedPresenter
    def initialize(service_instance)
      @service_instance = service_instance
    end

    def to_hash
      {
        label: "Unmanaged Service #{@service_instance.guid}",
        name: @service_instance.name
      }
    end
  end

  class ManagedPresenter
    def initialize(service_instance)
      @service_instance = service_instance
    end

    def to_hash
      {
        label: [@service_instance.service.label, @service_instance.service.version].join('-'),
        provider: @service_instance.service.provider,
        version: @service_instance.service.version,
        vendor: @service_instance.service.label,
        plan: @service_instance.service_plan.name,
        name: @service_instance.name
      }
    end
  end
end
