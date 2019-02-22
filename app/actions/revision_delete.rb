module VCAP::CloudController
  class RevisionDelete
    class << self
      def delete(revisions)
        Array(revisions).each do |revision|
          delete_metadata(revision)
          delete_process_commands(revision)
          revision.destroy
        end
      end

      def delete_metadata(revision)
        LabelDelete.delete(revision.labels)
        AnnotationDelete.delete(revision.annotations)
      end

      def delete_process_commands(revision)
        revision.process_commands.each(&:destroy)
      end
    end
  end
end
