module VCAP::CloudController
  class QuotaDefinition < Sequel::Model
    one_to_many :organizations

    attr_accessor :org_usage

    export_attributes :name, :non_basic_services_allowed, :total_services, :total_routes,
                      :memory_limit, :trial_db_allowed, :instance_memory_limit
    import_attributes :name, :non_basic_services_allowed, :total_services, :total_routes,
                      :memory_limit, :trial_db_allowed, :instance_memory_limit

    def validate
      validates_presence :name
      validates_unique :name
      validates_presence :non_basic_services_allowed
      validates_presence :total_services
      validates_presence :total_routes
      validates_presence :memory_limit

      errors.add(:memory_limit, :less_than_zero) if memory_limit && memory_limit < 0
      errors.add(:instance_memory_limit, :invalid_instance_memory_limit) if instance_memory_limit && instance_memory_limit < -1
    end

    def before_destroy
      if organizations.present?
        raise VCAP::Errors::ApiError.new_from_details('AssociationNotEmpty', 'organization', 'quota definition')
      end
    end

    def trial_db_allowed=(_)
    end

    def trial_db_allowed
      false
    end

    def self.configure(config)
      @default_quota_name = config[:default_quota_definition]
    end

    def to_hash(opts={})
      return super(opts) unless org_usage

      super(opts).merge!('org_usage' => org_usage)
    end

    class << self
      attr_reader :default_quota_name
    end

    def self.default
      self[name: @default_quota_name]
    end

    def self.user_visibility_filter(user)
      full_dataset_filter
    end
  end
end
