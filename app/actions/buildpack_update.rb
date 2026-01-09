require 'repositories/buildpack_event_repository'

module VCAP::CloudController
  class BuildpackUpdate
    class Error < ::StandardError
    end

    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def update(buildpack, message)
      Buildpack.db.transaction do
        Locking[name: 'buildpacks'].lock!

        MetadataUpdate.update(buildpack, message)

        buildpack.move_to(message.position) if message.requested?(:position)
        buildpack.stack = message.stack if message.requested?(:stack)
        buildpack.enabled = message.enabled if message.requested?(:enabled)
        buildpack.locked = message.locked if message.requested?(:locked)
        buildpack.name = message.name if message.requested?(:name)
        buildpack.save

        Repositories::BuildpackEventRepository.new.record_buildpack_update(buildpack, @user_audit_info, message.audit_hash)
      end
      buildpack
    rescue Sequel::ValidationFailed => e
      validation_error!(e, message)
    end

    private

    def validation_error!(error, message)
      error!(%(Stack '#{message.stack}' does not exist)) if error.errors.on(:stack)&.include?(:buildpack_stack_does_not_exist)
      error!(%(Buildpack stack cannot be changed)) if error.errors.on(:stack)&.include?(:buildpack_cant_change_stacks)
      error!(%(Buildpack with name '#{error.model.name}' and an unassigned stack already exists)) if error.errors.on(:stack)&.include?(:unique)

      if error.errors.on(%i[name stack lifecycle])&.include?(:unique)
        error!(%(Buildpack with name '#{error.model.name}', stack '#{error.model.stack}' and lifecycle '#{error.model.lifecycle}' already exists))
      end

      error!(error.message)
    end

    def error!(error_message)
      raise Error.new(error_message)
    end
  end
end
