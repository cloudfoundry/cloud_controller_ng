class SpaceCreate
  class Error < ::StandardError
  end

  def create(org, message)
    VCAP::CloudController::Space.create(name: message.name, organization: org)
  rescue Sequel::ValidationFailed => e
    validation_error!(e)
  end

  private

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
