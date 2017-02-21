module VCAP::CloudController
  class IsolationSegmentUnassign
    class IsolationSegmentUnassignError < StandardError; end

    def unassign(isolation_segment, org)
      isolation_segment.db.transaction do
        isolation_segment.lock!
        org.lock!

        space_association_error! if segment_associated_with_space?(isolation_segment, org)
        org_association_error! if is_default_segment?(isolation_segment, org)

        isolation_segment.remove_organization(org)
      end
    end

    private

    def segment_associated_with_space?(isolation_segment, organization)
      !Space.dataset.where(isolation_segment_model: isolation_segment, organization: organization).empty?
    end

    def is_default_segment?(isolation_segment, organization)
      organization.default_isolation_segment_model == isolation_segment
    end

    def space_association_error!
      raise IsolationSegmentUnassignError.new('Please delete the Space associations for your Isolation Segment.')
    end

    def org_association_error!
      raise CloudController::Errors::ApiError.new_from_details(
        'UnableToPerform',
        'Cannot unset the Default Isolation Segment.',
        'Please change the Default Isolation Segment for your Organization before attempting to remove the default.')
    end
  end
end
