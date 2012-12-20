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

    def self.populate_from_config(config)
      config = config[:quota_definitions][:memory]
      config.each do |k, v|
        MemoryQuotaDefinition.
          update_or_create(:name => k.to_s) do |r|
          r.update_from_hash(v)
        end
      end
    end
  end
end
