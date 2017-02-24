module VCAP::CloudController
  class IsolationSegmentDelete
    class AssociationNotEmptyError < StandardError; end

    def delete(isolation_segment_model)
      if isolation_segment_model.is_shared_segment?
        raise CloudController::Errors::ApiError.new_from_details('UnprocessableEntity',
          "Cannot delete the #{isolation_segment_model.name} Isolation Segment")
      end

      association_not_empty! unless isolation_segment_model.spaces.empty? && isolation_segment_model.organizations.empty?

      isolation_segment_model.db.transaction do
        isolation_segment_model.lock!
        isolation_segment_model.destroy
      end
    end

    private

    def association_not_empty!
      raise AssociationNotEmptyError.new('Revoke the Organization entitlements for your Isolation Segment.')
    end
  end
end
