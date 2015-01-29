module VCAP::CloudController
  class Event < Sequel::Model
    plugin :serialization

    many_to_one :space, without_guid_generation: true

    def validate
      validates_presence :type
      validates_presence :timestamp
      validates_presence :actor
      validates_presence :actor_type
      validates_presence :actee
      validates_presence :actee_type
      validates_not_null :actee_name
    end

    serialize_attributes :json, :metadata

    export_attributes :type, :actor, :actor_type, :actor_name, :actee,
      :actee_type, :actee_name, :timestamp, :metadata, :space_guid,
      :organization_guid

    def metadata
      super || {}
    end

    def before_save
      denormalize_space_and_org_guids
      super
    end

    def denormalize_space_and_org_guids
      return if space_guid && organization_guid
      self.space_guid = space.guid
      self.organization_guid = space.organization.guid
    end

    def self.user_visibility_filter(user)
      Sequel.or([
        [:space, user.audited_spaces_dataset],
        [:space, user.spaces_dataset],
        [:organization_guid, user.audited_organizations_dataset.map(&:guid)]
      ])
    end
  end
end
