module VCAP::CloudController
  class IsolationSegmentDelete
    def delete(isolation_segment_model)
      if isolation_segment_model.guid.eql?(VCAP::CloudController::IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID)
        raise CloudController::Errors::ApiError.new_from_details('UnprocessableEntity',
          "Cannot delete the #{isolation_segment_model.name} Isolation Segment")
      end

      raise CloudController::Errors::ApiError.new_from_details('AssociationNotEmpty', 'Space', 'Isolation Segment') unless isolation_segment_model.spaces.empty?
      raise CloudController::Errors::ApiError.new_from_details('AssociationNotEmpty', 'Organization', 'Isolation Segment') unless isolation_segment_model.organizations.empty?

      isolation_segment_model.db.transaction do
        isolation_segment_model.lock!
        isolation_segment_model.destroy
      end
    end
  end
end
