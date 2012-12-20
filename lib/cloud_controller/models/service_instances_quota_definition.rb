# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class ServiceInstancesQuotaDefinition < Sequel::Model

    export_attributes :name, :non_basic_services_allowed, :total_services
    import_attributes :name, :non_basic_services_allowed, :total_services

    def validate
      validates_presence :name
      validates_unique :name
      validates_presence :non_basic_services_allowed
      validates_presence :total_services
    end

    def self.populate_from_config(config)
      config = config[:quota_definitions][:service_instances]
      config.each do |k, v|
        ServiceInstancesQuotaDefinition.
          update_or_create(:name => k.to_s) do |r|
          r.update_from_hash(v)
        end
      end
    end

    def self.configure(config)
      default = config[:default_quota_definitions][:service_instances]
      @default_quota_name = default
    end

    def self.default
      @default ||= ServiceInstancesQuotaDefinition[:name => @default_quota_name]
    end
  end
end
