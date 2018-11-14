module VCAP::Services::ServiceBrokers::V2
  class ServiceInstanceSchema
    include CatalogValidationHelper

    attr_reader :errors, :create, :update

    def initialize(instance)
      @errors = VCAP::Services::ValidationErrors.new
      @instance = instance
      @create_data = instance['create']
      @update_data = instance['update']

      @path = ['service_instance']

      build_create
      build_update
    end

    def build_create
      @create = ParametersSchema.new(@create_data, @path + ['create']) if @create_data.is_a?(Hash)
    end

    def build_update
      @update = ParametersSchema.new(@update_data, @path + ['update']) if @update_data.is_a?(Hash)
    end

    def valid?
      return @valid if defined? @valid

      if @create_data
        validate_hash!(:create, @create_data)
        errors.add_nested(create, create.errors) if create && !create.valid?
      end

      if @update_data
        validate_hash!(:update, @update_data)
        errors.add_nested(update, update.errors) if update && !update.valid?
      end
      @valid = errors.empty?
    end

    private

    def human_readable_attr_name(name)
      {
        create: 'Schemas service_instance.create',
        update: 'Schemas service_instance.update',
      }.fetch(name) { raise NotImplementedError }
    end
  end
end
