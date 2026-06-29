# NOTE: This is a one-off backfill job. It populates the `lifecycle_type`
# column on `apps`, `droplets`, and `builds` for rows that pre-date the
# column's introduction. Once all installations have run it long enough to
# drain those rows, this job will be removed.
#
# Operators can also run `rake db:lifecycle_type_backfill` manually.

module VCAP::CloudController
  module Jobs
    module Runtime
      class LifecycleTypeBackfill < VCAP::CloudController::Jobs::CCJob
        BATCH_SIZE      = 1000
        BATCHES_PER_RUN = 10

        TABLES = [
          { table: :apps,     guid_column: :app_guid     },
          { table: :droplets, guid_column: :droplet_guid },
          { table: :builds,   guid_column: :build_guid   }
        ].freeze

        # Pass -1 for +batches_per_run+ to drain until no rows remain.
        def initialize(batch_size: BATCH_SIZE, batches_per_run: BATCHES_PER_RUN)
          super()
          @batch_size      = batch_size
          @batches_per_run = batches_per_run
        end

        def perform
          TABLES.each { |t| backfill(**t) }
        end

        def job_name_in_configuration
          :lifecycle_type_backfill
        end

        def max_attempts
          1
        end

        private

        def backfill(table:, guid_column:)
          return unless column_exists?(table, :lifecycle_type)

          total_rows = 0
          remaining_batches = @batches_per_run
          while remaining_batches != 0 # -1 means: drain until no rows remain
            updated_rows = update_batch(table, guid_column)
            total_rows += updated_rows
            break if updated_rows < @batch_size

            remaining_batches -= 1 if remaining_batches > 0
          end
          logger.info("lifecycle_type_backfill: updated #{total_rows} rows in #{table}") if total_rows > 0
        end

        def update_batch(table, guid_column)
          guids = db[table].where(lifecycle_type: nil).limit(@batch_size).select_map(:guid)
          return 0 if guids.empty?

          # If a row appears in both *_lifecycle_data tables (which it shouldn't), buildpack wins
          # (matches the runtime fallback in {app,build,droplet}_model.rb#lifecycle_type).
          guids_with_buildpack_lifecycle_data = db[:buildpack_lifecycle_data].where(guid_column => guids).select_map(guid_column)
          guids_with_cnb_lifecycle_data       = db[:cnb_lifecycle_data].where(guid_column => guids).select_map(guid_column) - guids_with_buildpack_lifecycle_data
          guids_without_lifecycle_data        = guids - guids_with_buildpack_lifecycle_data - guids_with_cnb_lifecycle_data

          db.transaction do
            update_lifecycle(table, guids_with_buildpack_lifecycle_data, BuildpackLifecycleDataModel::LIFECYCLE_TYPE)
            update_lifecycle(table, guids_with_cnb_lifecycle_data,       CNBLifecycleDataModel::LIFECYCLE_TYPE)
            update_lifecycle(table, guids_without_lifecycle_data,        DockerLifecycleDataModel::LIFECYCLE_TYPE)
          end

          guids.size
        end

        def update_lifecycle(table, guids, value)
          return if guids.empty?

          db[table].where(guid: guids, lifecycle_type: nil).update(lifecycle_type: value)
        end

        def column_exists?(table, column)
          db.schema(table, reload: true).map(&:first).include?(column)
        rescue Sequel::Error
          false
        end

        def db
          Sequel::Model.db
        end

        def logger
          @logger ||= Steno.logger('cc.background.lifecycle-type-backfill')
        end
      end
    end
  end
end
