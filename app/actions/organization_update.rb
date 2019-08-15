module VCAP::CloudController
  class OrganizationUpdate
    class Error < ::StandardError
    end

    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def update(org, message)
      org.db.transaction do
        org.lock!
        org.name = message.name if message.requested?(:name)
        LabelsUpdate.update(org, message.labels, OrganizationLabelModel)
        AnnotationsUpdate.update(org, message.annotations, OrganizationAnnotationModel)

        if message.requested?(:suspended)
          org.status = message.suspended ? Organization::SUSPENDED : Organization::ACTIVE
        end

        org.save
        Repositories::OrganizationEventRepository.new.record_organization_update(org, @user_audit_info, message.audit_hash)
      end

      org
    rescue Sequel::ValidationFailed => e
      validation_error!(e)
    end

    def validation_error!(error)
      if error.errors.on(:name)&.include?(:unique)
        error!('Name must be unique')
      end
      error!(error.message)
    end

    def error!(message)
      raise Error.new(message)
    end
  end
end
