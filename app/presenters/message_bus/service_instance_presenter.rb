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
        label: [
          @service_instance.service.label,
          @service_instance.service.version
        ].compact.join('-'),
        provider: @service_instance.service.provider,
        vendor: @service_instance.service.label,
        plan: @service_instance.service_plan.name,
        name: @service_instance.name,
        tags: @service_instance.merged_tags
      }.tap do |hash|
        if @service_instance.service.version
          hash[:version] = @service_instance.service.version
        end
      end
    end
  end
end
