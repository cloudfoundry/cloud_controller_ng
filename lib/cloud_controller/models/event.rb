module VCAP::CloudController::Models
  class Event < Sequel::Model
    plugin :single_table_inheritance, :type
    plugin :serialization

    many_to_one :space

    def validate
      validates_presence :type
      validates_presence :timestamp
      validates_presence :actor
      validates_presence :actor_type
      validates_presence :actee
      validates_presence :actee_type
    end

    serialize_attributes :json, :metadata

    export_attributes :type, :actor, :actor_type, :actee,
      :actee_type, :timestamp, :metadata, :space_guid

    def self.user_visibility_filter(user)
      user_visibility_filter_with_admin_override(
        # buckle up
        Sequel.|(
          {
            :space => user.audited_spaces_dataset
          }, {
            :space => user.spaces_dataset
          }
        )
      )
    end
  end
end