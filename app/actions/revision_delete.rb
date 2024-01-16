module VCAP::CloudController
  class RevisionDelete
    class << self
      def delete(revisions)
        Array(revisions).each do |revision|
          revision.process_commands.each(&:destroy)
          revision.destroy
        end
      end

      def delete_for_app(guid)
        RevisionModel.db.transaction do
          app_revisions_dataset = RevisionModel.where(app_guid: guid)
          RevisionSidecarProcessTypeModel.where(
            revision_sidecar_guid: RevisionSidecarModel.join(
              :revisions, guid: :revision_guid
            ).where(
              revisions__app_guid: guid
            ).select(:revision_sidecars__guid)
          ).delete
          RevisionSidecarModel.where(revision_guid: app_revisions_dataset.select(:guid)).delete
          RevisionProcessCommandModel.where(revision_guid: app_revisions_dataset.select(:guid)).delete
          RevisionLabelModel.where(resource_guid: app_revisions_dataset.select(:guid)).delete
          RevisionAnnotationModel.where(resource_guid: app_revisions_dataset.select(:guid)).delete
          app_revisions_dataset.delete
        end
      end
    end
  end
end
