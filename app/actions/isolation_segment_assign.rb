module VCAP::CloudController
  class IsolationSegmentAssign
    def assign(isolation_segment, organization)
      isolation_segment.db.transaction do
        isolation_segment.add_organization(organization)

        if organization.isolation_segment_models.length == 1
          set_default_segment(isolation_segment, organization)
        end
      end
    end

    private

    def set_default_segment(isolation_segment, organization)
      organization.lock!
      organization.update(isolation_segment_model: isolation_segment)
      organization.save
    end
  end
end
