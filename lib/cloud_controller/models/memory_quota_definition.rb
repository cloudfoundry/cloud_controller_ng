# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class MemoryQuotaDefinition < Sequel::Model

    export_attributes :name, :free_limit, :paid_limit
    import_attributes :name, :free_limit, :paid_limit

    def validate
      validates_presence :name
      validates_unique :name
      validates_presence :free_limit
      validates_presence :paid_limit
    end
  end
end
