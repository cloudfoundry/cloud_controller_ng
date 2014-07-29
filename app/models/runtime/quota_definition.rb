module VCAP::CloudController
  class QuotaDefinition < Sequel::Model

    one_to_many :organizations

    add_association_dependencies organizations: :destroy

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
    end

    def trial_db_allowed=(_)
    end

    def trial_db_allowed
      false
    end

    def self.configure(config)
      @default_quota_name = config[:default_quota_definition]
    end

    def self.default_quota_name
      @default_quota_name
    end

    def self.default
      self[:name => @default_quota_name]
    end

    def self.user_visibility_filter(user)
      full_dataset_filter
    end
  end
end
