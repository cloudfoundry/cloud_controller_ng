module VCAP::CloudController
  class QuotaDefinition < Sequel::Model
    one_to_many :organizations

    export_attributes :name, :non_basic_services_allowed, :total_services, :total_routes,
      :total_private_domains, :memory_limit, :trial_db_allowed, :instance_memory_limit,
      :app_instance_limit
    import_attributes :name, :non_basic_services_allowed, :total_services, :total_routes,
      :total_private_domains, :memory_limit, :trial_db_allowed, :instance_memory_limit,
      :app_instance_limit

    def validate
      validates_presence :name
      validates_unique :name
      validates_presence :non_basic_services_allowed
      validates_presence :total_services
      validates_presence :total_routes
      validates_presence :memory_limit

      errors.add(:memory_limit, :less_than_zero) if memory_limit && memory_limit < 0
      errors.add(:instance_memory_limit, :invalid_instance_memory_limit) if instance_memory_limit && instance_memory_limit < -1
      errors.add(:total_private_domains, :invalid_total_private_domains) if total_private_domains && total_private_domains < -1
      errors.add(:app_instance_limit, :invalid_app_instance_limit) if app_instance_limit && app_instance_limit < -1
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
