module VCAP::CloudController
  class IsolationSegmentDelete
    def delete(isolation_segment_model)
      if isolation_segment_model.is_shared_segment?
        raise CloudController::Errors::ApiError.new_from_details('UnprocessableEntity',
          "Cannot delete the #{isolation_segment_model.name} Isolation Segment")
      end

      isolation_segment_model.db.transaction do
        isolation_segment_model.lock!
        isolation_segment_model.destroy
      end
    end
  end
end
