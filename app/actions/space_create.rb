module VCAP::CloudController
  class SpaceCreate
    class Error < ::StandardError
    end

    def initialize(user_audit_info:)
      @user_audit_info = user_audit_info
    end

    def create(org, message)
      space = nil
      Space.db.transaction do
        space = VCAP::CloudController::Space.create(name: message.name, organization: org)
        MetadataUpdate.update(space, message)
        Repositories::SpaceEventRepository.new.record_space_create(space, user_audit_info, message.audit_hash)
      end

      space
    rescue Sequel::ValidationFailed => e
      validation_error!(e)
    end

    private

    attr_reader :user_audit_info

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
