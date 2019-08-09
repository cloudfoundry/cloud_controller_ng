module VCAP::CloudController
  class SpaceUpdate
    class Error < ::StandardError
    end

    def update(space, message)
      space.db.transaction do
        space.lock!
        space.name = message.name if message.requested?(:name)
        MetadataUpdate.update(space, message)

        space.save
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
