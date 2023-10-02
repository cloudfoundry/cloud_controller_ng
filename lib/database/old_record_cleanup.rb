require 'database/batch_delete'

module Database
  class OldRecordCleanup
    class NoCurrentTimestampError < StandardError; end
    attr_reader :model, :days_ago, :keep_at_least_one_record

    def initialize(model, days_ago, keep_at_least_one_record: false)
      @model = model
      @days_ago = days_ago
      @keep_at_least_one_record = keep_at_least_one_record
    end

    def delete
      cutoff_date = current_timestamp_from_database - days_ago.to_i.days

      old_records = model.dataset.where(Sequel.lit('created_at < ?', cutoff_date))
      if keep_at_least_one_record
        last_record = model.order(:id).last
        old_records = old_records.where(Sequel.lit('id < ?', last_record.id)) if last_record
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
