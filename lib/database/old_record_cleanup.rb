require 'database/batch_delete'

module Database
  class OldRecordCleanup
    STOPPED_EVENT_STATE = 'STOPPED'.freeze
    class NoCurrentTimestampError < StandardError; end
    attr_reader :model, :days_ago, :keep_at_least_one_record, :keep_running_app_records

    def initialize(model, days_ago, keep_at_least_one_record: false, keep_running_app_records: false)
      @model = model
      @days_ago = days_ago
      @keep_at_least_one_record = keep_at_least_one_record
      @keep_running_app_records = keep_running_app_records
    end

    def delete
      cutoff_date = current_timestamp_from_database - days_ago.to_i.days

      old_records = model.dataset.where(Sequel.lit('created_at < ?', cutoff_date))
      if keep_at_least_one_record
        last_id = model.order(:id).last.id
        old_records = old_records.where(Sequel.lit('id < ?', last_id))
      end

      if model.table_name.to_s == 'app_usage_events' && keep_running_app_records
        app_guids = old_records.where(state: STOPPED_EVENT_STATE).select(:app_guid)
        old_records = old_records.where(app_guid: app_guids)
      end

      logger.info("Cleaning up #{old_records.count} #{model.table_name} table rows")

      Database::BatchDelete.new(old_records, 1000).delete
    end

    private

    def current_timestamp_from_database
      # Evaluate the cutoff data upfront using the database's current time so that it remains the same
      # for each iteration of the batched delete
      model.db.fetch('SELECT CURRENT_TIMESTAMP as now').first[:now]
    end

    def logger
      @logger ||= Steno.logger('cc.old_record_cleanup')
    end
  end
end
