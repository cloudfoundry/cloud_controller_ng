module VCAP::CloudController
  class IsolationSegmentUpdate
    def update(isolation_segment, message)
      isolation_segment.db.transaction do
        isolation_segment.lock!
        isolation_segment.name = message.name if message.requested?(:name)
        isolation_segment.save
      end
    end
  end
end
