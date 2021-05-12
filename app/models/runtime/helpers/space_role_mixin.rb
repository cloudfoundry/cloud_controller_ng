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

    def validate
      validates_presence :space_id
      validates_presence :user_id
      validates_unique [:space_id, :user_id]
    end
  end
end
