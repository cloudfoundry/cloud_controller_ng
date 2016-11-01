module VCAP::CloudController
  class IsolationSegmentAssign
    def assign(isolation_segment, organizations)
      isolation_segment.db.transaction do
        isolation_segment.lock!

        organizations.sort! { |o1, o2| o1.guid <=> o2.guid }.each do |org|
          org.lock!
          isolation_segment.add_organization(org)

          if org.default_isolation_segment_model.nil?
            if isolation_segment.guid.eql?(VCAP::CloudController::IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID)
              org.update(default_isolation_segment_model: isolation_segment)
            end
          end
        end
      end
    end
  end
end
