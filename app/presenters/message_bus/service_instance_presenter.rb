class ServiceInstancePresenter
  def initialize(service_instance)
    @presenter = if service_instance.is_gateway_service
                   ManagedPresenter.new(service_instance)
                 else
                   ProvidedPresenter.new(service_instance)
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
        label: 'user-provided',
        name: @service_instance.name,
        tags: @service_instance.tags
      }
    end
  end

  class ManagedPresenter
    def initialize(service_instance)
      @service_instance = service_instance
    end

    def to_hash
      {
        label: @service_instance.service.label,
        provider: @service_instance.service.provider,
        plan: @service_instance.service_plan.name,
        name: @service_instance.name,
        tags: @service_instance.merged_tags
      }
    end
  end
end
