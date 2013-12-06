require 'models/services/service_broker/v2'

module VCAP::CloudController::ServiceBroker::V2
  class CatalogPlan
    attr_reader :broker_provided_id, :name, :description, :metadata, :catalog_service

    def initialize(catalog_service, attrs)
      @catalog_service    = catalog_service
      @broker_provided_id = attrs.fetch('id')
      @metadata           = attrs['metadata']
      @name               = attrs.fetch('name')
      @description        = attrs.fetch('description')
    end

    def cc_plan
      cc_service.service_plans_dataset.where(unique_id: broker_provided_id).first
    end

    delegate :cc_service, :to => :catalog_service
  end
end
