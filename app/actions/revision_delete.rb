module VCAP::CloudController
  class RevisionDelete
    class << self
      def delete(revisions)
        revisions.delete
      end

      def delete_for_app(guid)
        RevisionModel.where(app_guid: guid).delete
      end
    end
  end
end
