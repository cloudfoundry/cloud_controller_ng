module VCAP::CloudController
  class IsolationSegmentSelector
    class << self
      def for_space(space)
        shared_segment = VCAP::CloudController::IsolationSegmentModel.shared_segment

        if space.isolation_segment_model
          if space.isolation_segment_model.is_shared_segment?
            return space.isolation_segment_model.name
          end
        else
          for_org(space.organization, shared_segment)
        end
      end

      private

      def for_org(org, shared_segment)
        if org.default_isolation_segment_model && !org.default_isolation_segment_model.is_shared_segment?
          return org.default_isolation_segment_model.name
        end
      end
    end
  end
end
