require 'models/services/service_broker/v2'

module VCAP::CloudController::ServiceBroker::V2
  class CatalogPlan
    attr_reader :broker_provided_id, :name, :description, :metadata, :catalog_service, :errors

    def initialize(catalog_service, attrs)
      @catalog_service    = catalog_service
      @broker_provided_id = attrs['id']
      @metadata           = attrs['metadata']
      @name               = attrs['name']
      @description        = attrs['description']
      @errors             = []
    end

    def cc_plan
      cc_service.service_plans_dataset.where(unique_id: broker_provided_id).first
    end

    def valid?
      return @valid if defined? @valid
      validate!
      @valid = !errors.any?
    end

    delegate :cc_service, :to => :catalog_service

    private

    def validate!
      validate_string!(:broker_provided_id, broker_provided_id)
      validate_string!(:name, name)
      validate_string!(:description, description)
      validate_hash!(:metadata, metadata) if metadata
    end

    def validate_string!(name, input)
      @errors << "#{human_readable_attr_name(name)} should be a string, but had value #{input.inspect}" unless input.is_a? String
    end

    def validate_hash!(name, input)
      @errors << "#{human_readable_attr_name(name)} should be a hash, but had value #{input.inspect}" unless input.is_a? Hash
    end

    def human_readable_attr_name(name)
      case name
      when :broker_provided_id
        "plan id"
      when :name
        "plan name"
      when :description
        "plan description"
      when :metadata
        "plan metadata"
      end
    end
  end
end
