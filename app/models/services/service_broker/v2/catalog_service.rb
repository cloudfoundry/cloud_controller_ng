require 'models/services/service_broker/v2'

module VCAP::CloudController::ServiceBroker::V2
  class ValidationError < StandardError
  end

  class CatalogService
    attr_reader :service_broker, :broker_provided_id, :metadata, :name,
      :description, :bindable, :tags

    def initialize(service_broker, attrs)
      @service_broker     = service_broker
      @broker_provided_id = attrs['id']
      @metadata           = attrs['metadata']
      @name               = attrs['name']
      @description        = attrs['description']
      @bindable           = attrs['bindable']
      @tags               = attrs.fetch('tags', [])
      @plans              = attrs['plans']

      validate!
    end

    def plans_present?
      @plans && !@plans.empty?
    end

    def cc_service
      service_broker.services_dataset.where(unique_id: broker_provided_id).first
    end

    private

    attr_reader :plans

    def validate!
      validate_string!(:broker_provided_id, broker_provided_id)
      validate_string!(:name, name)
      validate_string!(:description, description)

      validate_bool!(:bindable, bindable)

      validate_array_of_strings!(:tags, tags)

      validate_hash!(:metadata, metadata) if metadata

      validate_array_of_hashes!(:plans, plans)
      validate_at_least_one_plan_present!
      validate_all_plan_ids_are_unique!
    rescue ValidationError => e
      raise VCAP::Errors::ServiceBrokerCatalogInvalid.new(e.message)
    end

    def validate_string!(name, input)
      raise ValidationError.new("#{human_readable_attr_name(name)} should be a string, but had value #{input.inspect}") unless input.is_a? String
    end

    def validate_bool!(name, input)
      raise ValidationError.new("#{human_readable_attr_name(name)} should be a boolean, but had value #{input.inspect}") unless is_a_bool?(input)
    end

    def validate_array_of_strings!(name, input)
      raise ValidationError.new("#{human_readable_attr_name(name)} should be an array of strings, but had value #{input.inspect}") unless input.is_a? Array
      input.each do |value|
        raise ValidationError.new("#{human_readable_attr_name(name)} should be an array of strings, but had value #{input.inspect}") unless value.is_a? String
      end
    end

    def validate_hash!(name, input)
      raise ValidationError.new("#{human_readable_attr_name(name)} should be a hash, but had value #{input.inspect}") unless input.is_a? Hash
    end

    def validate_array_of_hashes!(name, input)
      raise ValidationError.new("#{human_readable_attr_name(name)} should be an array of hashes, but had value #{input.inspect}") unless input.is_a? Array
      input.each do |value|
        raise ValidationError.new("#{human_readable_attr_name(name)} should be an array of hashes, but had value #{input.inspect}") unless value.is_a? Hash
      end
    end

    def validate_at_least_one_plan_present!
      raise ValidationError.new('each service must have at least one plan') if plans.empty?
    end

    def validate_all_plan_ids_are_unique!
      raise ValidationError.new('each plan ID must be unique') if plans.uniq{|plan| plan['id']} .count < plans.count
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
      else
        raise NotImplementedError.new
      end
    end
  end
end
