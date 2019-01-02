module VCAP::CloudController
  class RevisionCreate
    class << self
      def create(app)
        RevisionModel.db.transaction do
          next_version = calculate_next_version(app)

          if (existing_revision_for_version = RevisionModel.find(app: app, version: next_version))
            existing_revision_for_version.destroy
          end

          RevisionModel.create(app: app, version: next_version, droplet_guid: app.droplet_guid)
        end
      end

      private

      def calculate_next_version(app)
        previous_revision = app.latest_revision
        return 1 if previous_revision.nil? || previous_revision.version >= 9999

        previous_revision.version + 1
      end
    end
  end
end
