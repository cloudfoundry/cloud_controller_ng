module VCAP::Services::ServiceBrokers::V2
  class CatalogPlan
    include CatalogValidationHelper

    ALLOWED_MAINTENANCE_INFO_KEYS = ['version', 'description'].freeze

    attr_reader :broker_provided_id, :name, :description, :metadata, :maximum_polling_duration, :maintenance_info,
      :catalog_service, :errors, :free, :bindable, :schemas, :plan_updateable

    def initialize(catalog_service, attrs)
      @catalog_service    = catalog_service
      @broker_provided_id = attrs['id']
      @metadata           = attrs['metadata']
      @name               = attrs['name']
      @description        = attrs['description']
      @errors             = VCAP::Services::ValidationErrors.new
      @free               = attrs['free'].nil? ? true : attrs['free']
      @bindable           = attrs['bindable']
      @plan_updateable    = attrs['plan_updateable']
      @maximum_polling_duration = attrs['maximum_polling_duration']
      @maintenance_info = attrs['maintenance_info']
      build_schemas(attrs['schemas'])
    end

    def build_schemas(schemas)
      return if schemas.nil?

      @schemas_data = schemas

      if @schemas_data.is_a? Hash
        @schemas = CatalogSchemas.new(schemas)
      end
    end

    def valid?
      return @valid if defined? @valid

      validate!
      validate_schemas!
      @valid = errors.empty?
    end

    delegate :cc_service, to: :catalog_service

    private

    def validate!
      validate_string!(:broker_provided_id, broker_provided_id, required: true)
      validate_string!(:name, name, required: true)
      validate_description!(:description, description, required: true)
      validate_hash!(:metadata, metadata) if metadata
      validate_bool!(:free, free) if free
      validate_bool!(:bindable, bindable) if bindable
      validate_bool!(:plan_updateable, plan_updateable) if plan_updateable
      validate_integer!(:maximum_polling_duration, maximum_polling_duration) if maximum_polling_duration
      validate_hash!(:schemas, @schemas_data) if @schemas_data

      validate_maintenance_info! if @maintenance_info
    end

    def validate_maintenance_info!
      validate_hash!(:maintenance_info, @maintenance_info)
      validate_semver!(:maintenance_info_version, @maintenance_info['version'], required: true)
      validate_string!(:maintenance_info_description, @maintenance_info['description'])
      validate_length_as_json!(:maintenance_info, @maintenance_info, 2000)
      validate_maintenance_info_keys! if @maintenance_info.is_a?(Hash)
    end

    def validate_maintenance_info_keys!
      disallowed_attrs = @maintenance_info.slice!(*ALLOWED_MAINTENANCE_INFO_KEYS)
      extra_keys       = disallowed_attrs.keys
      if extra_keys.any?
        errors.add(%(#{human_readable_attr_name(:maintenance_info)} contains invalid key(s): #{extra_keys.join(', ')}))
      end
    end

    def validate_schemas!
      if schemas && !schemas.valid?
        errors.add_nested(schemas, schemas.errors)
      end
    end

    def human_readable_attr_name(name)
      {
        broker_provided_id:           'Plan id',
        name:                         'Plan name',
        description:                  'Plan description',
        metadata:                     'Plan metadata',
        free:                         'Plan free',
        bindable:                     'Plan bindable',
        plan_updateable:              'Plan updateable',
        schemas:                      'Plan schemas',
        maximum_polling_duration:     'Maximum polling duration',
        maintenance_info:             'Maintenance info',
        maintenance_info_version:     'Maintenance info version',
        maintenance_info_description: 'Maintenance info description',
      }.fetch(name) { raise NotImplementedError }
    end
  end
end
