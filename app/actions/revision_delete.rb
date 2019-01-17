module VCAP::CloudController
  class RevisionDelete
    class << self
      def delete(revisions)
        revisions.each do |revision|
          delete_metadata(revision)
          revision.destroy
        end
      end

      def delete_metadata(revision)
        LabelDelete.delete(revision.labels)
        AnnotationDelete.delete(revision.annotations)
      end
    end
  end
end
