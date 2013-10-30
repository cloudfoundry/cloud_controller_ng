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
  end
end