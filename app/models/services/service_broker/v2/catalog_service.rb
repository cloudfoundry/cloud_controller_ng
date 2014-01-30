require 'models/services/service_broker/v2'
require 'models/services/service_broker/v2/catalog_validation_helper'

module VCAP::CloudController::ServiceBroker::V2
  class CatalogService
    include CatalogValidationHelper

    attr_reader :service_broker, :broker_provided_id, :metadata, :name,
      :description, :bindable, :tags, :errors, :plans, :requires

    def initialize(service_broker, attrs)
      @service_broker     = service_broker
      @broker_provided_id = attrs['id']
      @metadata           = attrs['metadata']
      @name               = attrs['name']
      @description        = attrs['description']
      @bindable           = attrs['bindable']
      @tags               = attrs.fetch('tags', [])
      @requires           = attrs.fetch('requires', [])
      @plans_data         = attrs['plans']
      @errors             = []
      @plans              = []

      build_plans()
    end

    def valid?
      return @valid if defined? @valid
      validate_service
      validate_at_least_one_plan_present!
      validate_all_plan_ids_are_unique!
      validate_all_plan_names_are_unique!
      all_plans_valid = plans.map(&:valid?).all?
      @valid = !@errors.any? && all_plans_valid
    end

    def plans_present?
      @plans && !@plans.empty?
    end

    def cc_service
      service_broker.services_dataset.where(unique_id: broker_provided_id).first
    end

    private

    attr_reader :plans_data

    def validate_service
      validate_string!(:broker_provided_id, broker_provided_id, required: true)
      validate_string!(:name, name, required: true)
      validate_string!(:description, description, required: true)
      validate_bool!(:bindable, bindable, required: true)

      validate_array_of_strings!(:tags, tags)
      validate_array_of_strings!(:requires, requires)

      validate_hash!(:metadata, metadata) if metadata
    end

    def validate_plans_data
      errors_count = errors.count
      validate_array_of_hashes!(:plans, plans_data)
      return errors.count == errors_count
    end

    def build_plans
      if validate_plans_data
        @plans = @plans_data.map { |attrs| CatalogPlan.new(self, attrs) }
      end
    end

    def validate_at_least_one_plan_present!
      @errors << 'at least one plan is required' if plans.empty?
    end

    def validate_all_plan_ids_are_unique!
      @errors << 'plan id must be unique' if plans.uniq{ |plan| plan.broker_provided_id }.count < plans.count
    end

    def validate_all_plan_names_are_unique!
      @errors << 'plan names must be unique within a service' if plans.uniq { |plan| plan.name }.count < plans.count
    end

    def human_readable_attr_name(name)
      case name
      when :broker_provided_id
        'service id'
      when :name
        'service name'
      when :description
        'service description'
      when :bindable
        'service "bindable" field'
      when :tags
        'service tags'
      when :metadata
        'service metadata'
      when :plans
        'service plans list'
      when :requires
        'service "requires" field'
      else
        raise NotImplementedError.new
      end
    end
  end
end
