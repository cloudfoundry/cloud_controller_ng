# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class QuotaDefinition < Sequel::Model
    export_attributes :name, :non_basic_services_allowed, :total_services
    import_attributes :name, :non_basic_services_allowed, :total_services

    def validate
      validates_presence :name
      validates_unique :name
      validates_presence :non_basic_services_allowed
      validates_presence :total_services
    end
  end
end
