require 'models/services/service_broker/v2'

module VCAP::CloudController::ServiceBroker::V2
  class CatalogService
    attr_reader :service_broker, :broker_provided_id, :metadata, :name,
      :description, :bindable, :tags

    def initialize(service_broker, attrs)
      @service_broker     = service_broker
      @broker_provided_id = attrs.fetch('id')
      @metadata           = attrs['metadata']
      @name               = attrs.fetch('name')
      @description        = attrs.fetch('description')
      @bindable           = attrs.fetch('bindable')
      @tags               = attrs.fetch('tags', [])
      @plans_present      = !attrs.fetch('plans', []).empty?
    end

    def plans_present?
      @plans_present
    end

    def cc_service
      service_broker.services_dataset.where(unique_id: broker_provided_id).first
    end
  end
end
