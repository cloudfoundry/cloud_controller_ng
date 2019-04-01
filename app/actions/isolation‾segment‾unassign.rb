module VCAP::CloudController
  class IsolationSegmentUnassign
    def unassign(isolation_segment, org)
      isolation_segment.db.transaction do
        isolation_segment.lock!
        org.lock!

        org_association_error! if is_default_segment?(isolation_segment, org)

        spaces = associated_spaces(isolation_segment, org)
        space_association_error!(spaces) unless spaces.empty?

        isolation_segment.remove_organization(org)
      end
    end

    private

    def segment_associated_with_space?(isolation_segment, organization)
      !Space.dataset.where(isolation_segment_model: isolation_segment, organization: organization).empty?
    end

    def associated_spaces(isolation_segment, organization)
      Space.dataset.where(isolation_segment_model: isolation_segment, organization: organization)
    end

    def is_default_segment?(isolation_segment, organization)
      organization.default_isolation_segment_model == isolation_segment
    end

    def space_association_error!(associated_spaces)
      space_list = associated_spaces.map { |s| "'#{s.name}'" }.join(', ')
      raise CloudController::Errors::ApiError.new_from_details(
        'UnprocessableEntity',
        "Cannot remove the entitlement while this Isolation Segment is assigned to any Spaces. Currently assigned to: #{space_list}",
      )
    end

    def org_association_error!
      raise CloudController::Errors::ApiError.new_from_details(
        'UnprocessableEntity',
        'Cannot remove the entitlement while this Isolation Segment is assigned as the Default Isolation Segment for the Organization.',
      )
    end
  end
end
