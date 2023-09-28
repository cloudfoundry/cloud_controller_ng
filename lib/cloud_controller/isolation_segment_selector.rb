module VCAP::CloudController
  class IsolationSegmentSelector
    class << self
      def for_space(space)
        if space.isolation_segment_model
          space.isolation_segment_model.name unless space.isolation_segment_model.is_shared_segment?
        else
          for_org(space.organization)
        end
      end

      private

      def for_org(org)
        return unless org.default_isolation_segment_model && !org.default_isolation_segment_model.is_shared_segment?

        org.default_isolation_segment_model.name
      end
    end
  end
end
