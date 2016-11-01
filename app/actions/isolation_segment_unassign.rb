module VCAP::CloudController
  class IsolationSegmentUnassign
    class IsolationSegmentUnassignError < StandardError; end

    def unassign(isolation_segment, organizations)
      isolation_segment.db.transaction do
        isolation_segment.lock!

        organizations.sort! { |o1, o2| o1.guid <=> o2.guid }.each do |org|
          org.lock!
          space_association_error! if segment_associated_with_space?(isolation_segment, org)

          unset_default_segment(isolation_segment, org)

          isolation_segment.remove_organization(org)
        end
      end
    end

    private

    def segment_associated_with_space?(isolation_segment, organization)
      !Space.dataset.where(isolation_segment_model: isolation_segment, organization: organization).empty?
    end

    def is_default_segment?(isolation_segment, organization)
      organization.default_isolation_segment_model == isolation_segment
    end

    def unset_default_segment(isolation_segment, organization)
      if is_default_segment?(isolation_segment, organization)
        organization.check_spaces_without_isolation_segments_empty!('Removing')

        organization.update(default_isolation_segment_guid: nil)
      end
    end

    def space_association_error!
      raise IsolationSegmentUnassignError.new('Please delete the Space associations for your Isolation Segment.')
    end
  end
end
