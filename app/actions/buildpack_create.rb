module VCAP::CloudController
  class BuildpackCreate
    class Error < ::StandardError
    end

    DEFAULT_POSITION = 1
    DEFAULT_ENABLED = true
    DEFAULT_LOCKED = false

    def create(message)
      Buildpack.db.transaction do
        Locking[name: 'buildpacks'].lock!

        buildpack = Buildpack.create(
          name: message.name,
          stack: message.stack,
          enabled: (message.enabled.nil? ? DEFAULT_ENABLED : message.enabled),
          locked: (message.locked.nil? ? DEFAULT_LOCKED : message.locked),
        )

        MetadataUpdate.update(buildpack, message)

        buildpack.move_to(message.position || DEFAULT_POSITION)
      end
    rescue Sequel::ValidationFailed => e
      validation_error!(e, message)
    end

    def validation_error!(error, create_message)
      if error.errors.on(:stack)&.include?(:buildpack_stack_does_not_exist)
        error!(%{Stack '#{create_message.stack}' does not exist})
      end
      if error.errors.on([:name, :stack])&.include?(:unique)
        error!(%{Buildpack with name '#{error.model.name}' and stack '#{error.model.stack}' already exists})
      end
      if error.errors.on(:stack)&.include?(:unique)
        error!(%{Buildpack with name '#{error.model.name}' and an unassigned stack already exists})
      end

      error!(error.message)
    end

    def error!(error_message)
      raise Error.new(error_message)
    end
  end
end
