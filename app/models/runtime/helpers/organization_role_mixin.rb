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

    def validate
      validates_unique [:organization_id, :user_id]
      validates_presence :organization_id
      validates_presence :user_id
    end
  end
end
