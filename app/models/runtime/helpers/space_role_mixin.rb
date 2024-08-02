module VCAP::CloudController
  module SpaceRoleMixin
    def self.included(included_class)
      included_class.class_eval <<-RUBY, __FILE__, __LINE__ + 1
        many_to_one :user
        many_to_one :space

        def_column_alias :guid, :role_guid
      RUBY
    end

    def before_create
      self.guid ||= SecureRandom.uuid
    end

    def around_save
      yield
    rescue Sequel::UniqueConstraintViolation => e
      unique_indexes = %w[space_developers_idx space_auditors_idx space_managers_idx spaces_supporters_user_space_index]
      raise e unless unique_indexes.any? { |pattern| e.message.include?(pattern) }

      errors.add(%i[space_id user_id], :unique)
      raise validation_failed_error
    end

    def validate
      validates_presence :space_id
      validates_presence :user_id
      validates_unique %i[space_id user_id]
    end
  end
end
