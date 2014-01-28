require 'models/services/service_broker/v2'

module VCAP::CloudController::ServiceBroker::V2
  class CatalogService
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

    def validate_string!(name, input, opts={})
      if !input.is_a?(String) && !input.nil?
        @errors << "#{human_readable_attr_name(name)} should be a string, but had value #{input.inspect}"
        return
      end

      if opts[:required] && (input.nil? || input.empty?)
        @errors << "#{human_readable_attr_name(name)} must be non-empty and a string"
      end
    end

    def validate_bool!(name, input, opts={})
      if !is_a_bool?(input) && !input.nil?
        @errors << "#{human_readable_attr_name(name)} should be a boolean, but had value #{input.inspect}"
        return
      end

      if opts[:required] && input.nil?
        @errors << "#{human_readable_attr_name(name)} must be present and a boolean"
      end
    end

    def validate_array_of_strings!(name, input)
      unless input.is_a? Array
        @errors << "#{human_readable_attr_name(name)} should be an array of strings, but had value #{input.inspect}"
        return
      end

      input.each do |value|
        @errors << "#{human_readable_attr_name(name)} should be an array of strings, but had value #{input.inspect}" unless value.is_a? String
      end
    end

    def validate_hash!(name, input)
      @errors << "#{human_readable_attr_name(name)} should be a hash, but had value #{input.inspect}" unless input.is_a? Hash
    end

    def validate_array_of_hashes!(name, input)
      unless input.is_a? Array
        @errors << "#{human_readable_attr_name(name)} should be an array of hashes, but had value #{input.inspect}"
        return
      end

      input.each do |value|
        @errors << "#{human_readable_attr_name(name)} should be an array of hashes, but had value #{input.inspect}" unless value.is_a? Hash
      end
    end

    def validate_at_least_one_plan_present!
      @errors << 'each service must have at least one plan' if plans.empty?
    end

    def validate_all_plan_ids_are_unique!
      @errors << 'each plan ID must be unique' if plans.uniq{ |plan| plan.broker_provided_id }.count < plans.count
    end

    def is_a_bool?(value)
      [true, false].include?(value)
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
