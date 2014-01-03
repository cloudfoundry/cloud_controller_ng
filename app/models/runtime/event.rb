require "repositories/runtime/event_repository"

module VCAP::CloudController
  class Event < Sequel::Model
    plugin :serialization

    many_to_one :space, :without_guid_generation => true

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
      :actee_type, :timestamp, :metadata, :space_guid,
      :organization_guid

    def metadata
      super || {}
    end

    def space
      super || DeletedSpace.new
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
        [:space, user.spaces_dataset]
      ])
    end

    def self.create_app_exit_event(app, droplet_exited_payload)
      event_repository = Repositories::Runtime::EventRepository.new
      event_repository.create_app_exit_event(app, droplet_exited_payload)
    end

    def self.record_app_update(app, actor, request_attrs)
      event_repository = Repositories::Runtime::EventRepository.new
      event_repository.record_app_update(app, actor, request_attrs)
    end

    def self.record_app_create(app, actor, request_attrs)
      event_repository = Repositories::Runtime::EventRepository.new
      event_repository.record_app_create(app, actor, request_attrs)
    end

    def self.record_app_delete_request(deleting_app, actor, recursive)
      event_repository = Repositories::Runtime::EventRepository.new
      event_repository.record_app_delete_request(deleting_app, actor, recursive)
    end

    def self.record_space_create(space, actor, request_attrs)
      event_repository = Repositories::Runtime::EventRepository.new
      event_repository.record_space_create(space, actor, request_attrs)
    end

    def self.record_space_update(space, actor, request_attrs)
      event_repository = Repositories::Runtime::EventRepository.new
      event_repository.record_space_update(space, actor, request_attrs)
    end

    def self.record_space_delete_request(space, actor, recursive)
      event_repository = Repositories::Runtime::EventRepository.new
      event_repository.record_space_delete_request(space, actor, recursive)
    end
  end
end
