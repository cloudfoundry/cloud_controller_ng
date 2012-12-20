# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class QuotaDefinition < Sequel::Model

    export_attributes :name, :non_basic_services_allowed, :total_services,
                      :free_memory_limit, :paid_memory_limit
    import_attributes :name, :non_basic_services_allowed, :total_services,
                      :free_memory_limit, :paid_memory_limit

    def validate
      validates_presence :name
      validates_unique :name
      validates_presence :non_basic_services_allowed
      validates_presence :total_services
      validates_presence :free_memory_limit
      validates_presence :paid_memory_limit
    end

    def self.populate_from_config(config)
      config[:quota_definitions].each do |k, v|
        QuotaDefinition.update_or_create(:name => k.to_s) do |r|
          r.update_from_hash(v)
        end
      end
    end

    def self.configure(config)
      @default_quota_name = config[:default_quota_definition]
    end

    def self.default
      @default ||= QuotaDefinition[:name => @default_quota_name]
    end
  end
end
