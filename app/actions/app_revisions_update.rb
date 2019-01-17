module VCAP::CloudController
  class AppRevisionsUpdate
    class InvalidAppRevisions < StandardError
    end

    def initialize
      @logger = Steno.logger('cc.action.revision_update')
    end

    def update(revision, message)
      if message.requested?(:metadata)
        revision.db.transaction do
          LabelsUpdate.update(revision, message.labels, RevisionLabelModel)
          AnnotationsUpdate.update(revision, message.annotations, RevisionAnnotationModel)
        end
        @logger.info("Finished updating metadata on revision #{revision.guid}")
      end
      revision
    rescue Sequel::ValidationFailed => e
      raise InvalidAppRevisions.new(e.message)
    end
  end
end
