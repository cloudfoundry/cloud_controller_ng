class SpaceCreate
  class Error < ::StandardError
  end

  def create(org, message)
    missing_org! unless org

    VCAP::CloudController::Space.create(name: message.name, organization: org)
  rescue Sequel::ValidationFailed => e
    validation_error!(e)
  end

  private

  def missing_org!
    error!('Invalid organization. Ensure the organization exists and you have access to it.')
  end

  def validation_error!(error)
    if error.errors.on([:organization_id, :name])&.include?(:unique)
      error!('Name must be unique per organization')
    end
    error!(error.message)
  end

  def error!(message)
    raise Error.new(message)
  end
end
