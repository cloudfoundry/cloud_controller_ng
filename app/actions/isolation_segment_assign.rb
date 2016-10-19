module VCAP::CloudController
  class IsolationSegmentAssign
    def initialize
      @logger = Steno.logger('cc.action.isolation_segment_assign')
    end

    def assign(isolation_segment, organization)
      isolation_segment.db.transaction do
        isolation_segment.add_organization(organization)

        if organization.isolation_segment_models.length == 1
          organization.lock!
          organization.update(isolation_segment_model: isolation_segment)
          organization.save
        end
      end
    end
  end
end
