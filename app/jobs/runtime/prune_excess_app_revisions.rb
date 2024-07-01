module VCAP::CloudController
  module Jobs
    module Runtime
      class PruneExcessAppRevisions < VCAP::CloudController::Jobs::CCJob
        attr_accessor :max_retained_revisions_per_app

        def initialize(max_retained_revisions_per_app)
          @max_retained_revisions_per_app = max_retained_revisions_per_app
        end

        def perform
          logger = Steno.logger('cc.background')
          logger.info('Cleaning up excess app revisions')

          AppModel.select_map(:guid).each do |app_guid|
            revision_dataset = RevisionModel.where(app_guid:)
            next if revision_dataset.count <= max_retained_revisions_per_app

            revisions_to_keep = revision_dataset.order(Sequel.desc(:created_at), Sequel.desc(:id)).
                                limit(max_retained_revisions_per_app).
                                select(:id)

            revisions_to_delete = revision_dataset.exclude(id: revisions_to_keep)

            delete_count = RevisionDelete.delete(revisions_to_delete)
            logger.info("Cleaned up #{delete_count} revision rows for app #{app_guid}")
          end
        end

        def job_name_in_configuration
          :prune_excess_app_revisions
        end

        def max_attempts
          1
        end
      end
    end
  end
end
