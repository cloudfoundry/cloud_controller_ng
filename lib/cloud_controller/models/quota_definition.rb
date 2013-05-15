# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class QuotaDefinition < Sequel::Model

    one_to_many :organizations

    add_association_dependencies :organizations => :destroy

    export_attributes :name, :non_basic_services_allowed, :total_services,
                      :memory_limit, :trial_db_allowed
    import_attributes :name, :non_basic_services_allowed, :total_services,
                      :memory_limit, :trial_db_allowed
    ci_attributes     :name

    def validate
      validates_presence :name
      validates_unique_ci :name
      validates_presence :non_basic_services_allowed
      validates_presence :total_services
      validates_presence :memory_limit
    end

    def self.configure(config)
      @default_quota_name = config[:default_quota_definition]
    end

    def self.default
      @default ||= QuotaDefinition[:name => @default_quota_name]
    end
  end
end
