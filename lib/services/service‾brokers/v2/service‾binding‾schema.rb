module VCAP::Services::ServiceBrokers::V2
  class ServiceBindingSchema
    include CatalogValidationHelper

    attr_reader :errors, :create

    def initialize(instance)
      @errors = VCAP::Services::ValidationErrors.new
      @instance = instance
      @create_data = instance['create']

      @path = ['service_binding']

      build_create
    end

    def build_create
      return unless @create_data

      @create = ParametersSchema.new(@create_data, @path + ['create']) if @create_data.is_a?(Hash)
    end

    def valid?
      return @valid if defined? @valid

      if @create_data
        validate_hash!(:create, @create_data)
        errors.add_nested(create, create.errors) if create && !create.valid?
      end
      @valid = errors.empty?
    end

    private

    def human_readable_attr_name(name)
      {
        create: 'Schemas service_binding.create',
      }.fetch(name) { raise NotImplementedError }
    end
  end
end
