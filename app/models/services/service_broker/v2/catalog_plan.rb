require 'models/services/service_broker/v2'
require 'models/services/service_broker/v2/catalog_validation_helper'

module VCAP::CloudController::ServiceBroker::V2
  class CatalogPlan
    include CatalogValidationHelper

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
      validate_string!(:broker_provided_id, broker_provided_id, required: true)
      validate_string!(:name, name, required: true)
      validate_string!(:description, description, required: true)
      validate_hash!(:metadata, metadata) if metadata
    end

    def human_readable_attr_name(name)
      {
        broker_provided_id: "Plan id",
        name: "Plan name",
        description: "Plan description",
        metadata: "Plan metadata"
      }.fetch(name) { raise NotImplementedError }
    end
  end
end
