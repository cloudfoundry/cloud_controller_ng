module VCAP::CloudController
  class IsolationSegmentUpdate
    class InvalidIsolationSegment < StandardError; end

    def update(isolation_segment, message)
      isolation_segment.db.transaction do
        isolation_segment.lock!

        check_not_shared!(isolation_segment)
        check_no_apps_in_segment!(isolation_segment)

        isolation_segment.name = message.name if message.requested?(:name)
        isolation_segment.save
      end
    rescue Sequel::ValidationFailed => e
      raise InvalidIsolationSegment.new(e.message)
    end

    private

    def check_not_shared!(isolation_segment)
      if isolation_segment.is_shared_segment?
        raise CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', 'Cannot update the shared Isolation Segment')
      end
    end

    # In this function we are using these lookup queries rather than doing something of the form
    # isolation_segment.organizations.sort.each { ... }. Which would then also need to iterate over all
    # of the spaces within each organization.
    def check_no_apps_in_segment!(isolation_segment)
      org_dataset = Organization.dataset.where(guid: isolation_segment.organizations.map(&:guid), default_isolation_segment_model: isolation_segment)

      unless AppModel.dataset.where(space: Space.dataset.where(isolation_segment_guid: nil, organization: org_dataset)).empty?
        raise CloudController::Errors::ApiError.new_from_details(
          'UnableToPerform',
          "Updating Isolation Segment with name #{isolation_segment.name}",
          "Please delete all Apps from Spaces without assigned Isolation Segments in any Organization were #{isolation_segment.name} is the default.")
      end

      unless AppModel.dataset.where(space: Space.dataset.where(isolation_segment_guid: isolation_segment.guid)).empty?
        raise CloudController::Errors::ApiError.new_from_details(
          'UnprocessableEntity',
          "Cannot update the #{isolation_segment.name} Isolation Segment when associated spaces contain apps")
      end
    end
  end
end
