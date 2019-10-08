module VCAP::CloudController
  class SpaceManager < Sequel::Model(:spaces_managers)
    many_to_one :user
    many_to_one :space

    def validate
      validates_unique [:space_id, :user_id]
      validates_presence :space_id
      validates_presence :user_id
    end

    def type
      @type ||= RoleTypes::SPACE_MANAGER
    end
  end
end
