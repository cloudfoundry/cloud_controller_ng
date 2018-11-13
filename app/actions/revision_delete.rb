module VCAP::CloudController
  class RevisionDelete
    def self.delete(revision)
      revision.each(&:destroy)
    end
  end
end
