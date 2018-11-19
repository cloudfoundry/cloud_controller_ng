module VCAP::Services::ServiceBrokers::V2
  class CatalogSchemas
    include CatalogValidationHelper

    attr_reader :errors, :service_instance, :service_binding

    def initialize(schemas)
      @errors = VCAP::Services::ValidationErrors.new
      @schemas = schemas

      @service_instance_data = schemas['service_instance']
      @service_binding_data = schemas['service_binding']

      build_instance
      build_binding
    end

    def build_instance
      return unless @schemas['service_instance']

      @service_instance_data = @schemas['service_instance']
      @service_instance = ServiceInstanceSchema.new(@service_instance_data) if @service_instance_data.is_a?(Hash)
    end

    def build_binding
      return unless @schemas['service_binding']

      @service_binding_data = @schemas['service_binding']
      @service_binding = ServiceBindingSchema.new(@service_binding_data) if @service_binding_data.is_a?(Hash)
    end

    def valid?
      return @valid if defined? @valid

      if @service_instance_data
        validate_hash!(:service_instance, @service_instance_data)
        errors.add_nested(service_instance, service_instance.errors) if service_instance && !service_instance.valid?
      end

      if @service_binding_data
        validate_hash!(:service_binding, @service_binding_data)
        errors.add_nested(service_binding, service_binding.errors) if service_binding && !service_binding.valid?
      end

      @valid = errors.empty?
    end

    private

    def human_readable_attr_name(name)
      {
        schemas: 'Schemas',
        service_instance: 'Schemas service_instance',
        service_binding: 'Schemas service_binding',
      }.fetch(name) { raise NotImplementedError }
    end
  end
end
