module VCAP::CloudController
  class IsolationSegmentUnassign
    def initialize
      @logger = Steno.logger('cc.action.isolation_segment_unassign')
    end

    def unassign(isolation_segment, organization)
      if isolation_segment_associated_with_space?(isolation_segment, organization)
        raise CloudController::Errors::ApiError.new_from_details('AssociationNotEmpty', 'Space', 'Isolation Segment')
      end

      segment_guids = organization.isolation_segment_models.map(&:guid)

      if segment_guids.length > 1 && organization.isolation_segment_model == isolation_segment
        raise CloudController::Errors::ApiError.new_from_details('UnableToPerform',
          "Removal of Isolation Segment #{isolation_segment.name} from Organization #{organization.name}",
          'This operation can only be completed if another Isolation Segment is set as the default')
      end

      if segment_guids.length == 1
        if segment_guids.include?(isolation_segment.guid)
          organization.lock!
          organization.update(default_isolation_segment_guid: nil)
        end
      end

      isolation_segment.remove_organization(organization)
    end

    private

    def isolation_segment_associated_with_space?(isolation_segment, organization)
      !Space.dataset.where(isolation_segment_model: isolation_segment, organization: organization).empty?
    end
  end
end
