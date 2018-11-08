module VCAP::CloudController
  class SpaceUpdate
    class Error < ::StandardError
    end

    def update(space, message)
      space.db.transaction do
        space.lock!
        space.name = message.name if message.requested?(:name)
        space.save
      end

      space
    rescue Sequel::ValidationFailed => e
      validation_error!(e)
    end

    def validation_error!(error)
      if error.is_a?(Space::DBNameUniqueRaceError) || error.errors.on([:organization_id, :name])&.include?(:unique)
        error!('Name must be unique per organization')
      end
      error!(error.message)
    end

    def error!(message)
      raise Error.new(message)
    end
  end
end
