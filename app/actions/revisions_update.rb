module VCAP::CloudController
  class RevisionsUpdate
    class InvalidAppRevisions < StandardError
    end

    def initialize
      @logger = Steno.logger('cc.action.revision_update')
    end

    def update(revision, message)
      revision.db.transaction do
        MetadataUpdate.update(revision, message)
      end
      @logger.info("Finished updating metadata on revision #{revision.guid}")
      revision
    rescue Sequel::ValidationFailed => e
      raise InvalidAppRevisions.new(e.message)
    end
  end
end
