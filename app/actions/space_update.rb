module VCAP::CloudController
  class SpaceUpdate
    class Error < ::StandardError
    end

    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def update(space, message)
      space.db.transaction do
        space.lock!
        space.name = message.name if message.requested?(:name)
        MetadataUpdate.update(space, message)

        space.save
        Repositories::SpaceEventRepository.new.record_space_update(space, @user_audit_info, message.audit_hash)
      end

      space
    rescue Sequel::ValidationFailed => e
      validation_error!(e, space)
    end

    def validation_error!(error, space)
      if error.is_a?(Space::DBNameUniqueRaceError) || error.errors.on([:organization_id, :name])&.include?(:unique)
        error!("Organization '#{space.organization.name}' already contains a space with name '#{space.name}'.")
      end
      error!(error.message)
    end

    def error!(message)
      raise Error.new(message)
    end
  end
end
