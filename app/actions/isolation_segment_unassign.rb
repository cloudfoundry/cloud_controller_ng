module VCAP::CloudController
  class IsolationSegmentUnassign
    class IsolationSegmentUnassignError < StandardError; end

    def unassign(isolation_segment, organization)
      space_association_error! if segment_associated_with_space?(isolation_segment, organization)

      segment_guids = organization.isolation_segment_models.map(&:guid)

      if multiple_remaining_segments?(segment_guids) && is_default_segment?(isolation_segment, organization)
        delete_default_error!(isolation_segment, organization)
      end

      if single_remaining_segment?(segment_guids) && segment_guids.include?(isolation_segment.guid)
        unset_default_segment(organization)
      end

      isolation_segment.remove_organization(organization)
    end

    private

    def segment_associated_with_space?(isolation_segment, organization)
      !Space.dataset.where(isolation_segment_model: isolation_segment, organization: organization).empty?
    end

    def is_default_segment?(isolation_segment, organization)
      organization.isolation_segment_model == isolation_segment
    end

    def multiple_remaining_segments?(segment_guids)
      segment_guids.length > 1
    end

    def single_remaining_segment?(segment_guids)
      segment_guids.length == 1
    end

    def unset_default_segment(organization)
      organization.lock!
      organization.update(default_isolation_segment_guid: nil)
    end

    def space_association_error!
      raise IsolationSegmentUnassignError.new('Please delete the Space associations for your Isolation Segment.')
    end

    def delete_default_error!(isolation_segment, organization)
      raise IsolationSegmentUnassignError.new(
        "Removal of Isolation Segment #{isolation_segment.name} from Organization #{organization.name} could not be completed: " \
          'This operation can only be completed if another Isolation Segment is set as the default'
      )
    end
  end
end
