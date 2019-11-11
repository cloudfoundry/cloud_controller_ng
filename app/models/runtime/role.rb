module VCAP::CloudController
  class Role < Sequel::Model
    def user_guid
      User.first(id: user_id).guid
    end

    def organization_guid
      Organization.first(id: organization_id)&.guid
    end

    def space_guid
      Space.first(id: space_id)&.guid
    end
  end
end
