module VCAP::CloudController
  class IsolationSegmentCreate
    class Error < ::StandardError
    end

    def self.create(message)
      isolation_segment = nil
      IsolationSegmentModel.db.transaction do
        isolation_segment = IsolationSegmentModel.create(
          name: message.name,
        )
        if message.requested?(:metadata)
          LabelsUpdate.update(isolation_segment, message.labels, IsolationSegmentLabelModel)
          AnnotationsUpdate.update(isolation_segment, message.annotations, IsolationSegmentAnnotationModel)
        end
      end

      isolation_segment
    rescue Sequel::ValidationFailed => e
      raise Error.new(e.message)
    end
  end
end
