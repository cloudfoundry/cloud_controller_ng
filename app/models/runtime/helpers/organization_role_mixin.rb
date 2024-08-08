module VCAP::CloudController
  module OrganizationRoleMixin
    def self.included(included_class)
      included_class.class_eval <<-RUBY, __FILE__, __LINE__ + 1
        many_to_one :user
        many_to_one :organization

        def_column_alias :guid, :role_guid
      RUBY
    end

    def before_create
      self.guid ||= SecureRandom.uuid
    end

    def around_save
      yield
    rescue Sequel::UniqueConstraintViolation => e
      unique_indexes = %w[org_users_idx org_auditors_idx org_managers_idx org_billing_managers_idx]
      raise e unless unique_indexes.any? { |pattern| e.message.include?(pattern) }

      errors.add(%i[organization_id user_id], :unique)
      raise validation_failed_error
    end

    def validate
      validates_unique %i[organization_id user_id]
      validates_presence :organization_id
      validates_presence :user_id
    end
  end
end
