module VCAP::CloudController
  class BillingEvent < Sequel::Model
    plugin :single_table_inheritance, :kind,
           :key_chooser => proc { |instance| instance.model },
           :model_map => proc { |instance| instance.to_s.gsub("::Models::", "::") }

    def validate
      validates_presence :timestamp
      validates_presence :organization_guid
      validates_presence :organization_name
    end

    def self.create(values = {}, &block)
      if VCAP::CloudController::Config.config[:billing_event_writing_enabled]
        super(values, &block)
      end
    end
  end
end
