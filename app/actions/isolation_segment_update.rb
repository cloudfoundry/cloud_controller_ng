module VCAP::CloudController
  class IsolationSegmentUpdate
    class InvalidIsolationSegment < StandardError; end

    def update(isolation_segment, message)
      isolation_segment.db.transaction do
        isolation_segment.lock!

        check_not_shared!(isolation_segment)
        check_not_assigned!(isolation_segment)

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

    def check_not_assigned!(isolation_segment)
      error = CloudController::Errors::ApiError.new_from_details(
        'UnprocessableEntity',
        'Cannot update Isolation Segments that are assigned as the default for an Organization or Space.'
      )

      raise error unless Organization.dataset.where(default_isolation_segment_model: isolation_segment).empty?
      raise error unless Space.dataset.where(isolation_segment_guid: isolation_segment.guid).empty?
    end
  end
end
