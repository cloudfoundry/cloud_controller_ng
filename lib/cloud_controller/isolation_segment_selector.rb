module VCAP::CloudController
  class IsolationSegmentSelector
    class << self
      def for_space(space)
        if space.isolation_segment_model
          if !space.isolation_segment_model.is_shared_segment?
            space.isolation_segment_model.name
          end
        else
          for_org(space.organization)
        end
      end

      private

      def for_org(org)
        if org.default_isolation_segment_model && !org.default_isolation_segment_model.is_shared_segment?
          org.default_isolation_segment_model.name
        end
      end
    end
  end
end
