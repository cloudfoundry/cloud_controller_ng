require 'database/batch_delete'

module Database
  class OldRecordCleanup
    class NoCurrentTimestampError < StandardError; end
    attr_reader :model, :days_ago, :keep_at_least_one_record, :keep_running_records

    def initialize(model, cutoff_age_in_days:, keep_at_least_one_record: false, keep_running_records: false)
      @model = model
      @days_ago = cutoff_age_in_days
      @keep_at_least_one_record = keep_at_least_one_record
      @keep_running_records = keep_running_records
    end

    def delete
      cutoff_date = current_timestamp_from_database - days_ago.to_i.days

      old_records = model.dataset.where(Sequel.lit('created_at < ?', cutoff_date))
      if keep_at_least_one_record
        last_record = model.order(:id).last
        old_records = old_records.where(Sequel.lit('id < ?', last_record.id)) if last_record
      end
      logger.info("Cleaning up #{old_records.count} #{model.table_name} table rows")

      old_records = exclude_running_records(old_records) if keep_running_records

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

    def exclude_running_records(old_records)
      return old_records unless has_duration?(model)

      beginning_string = beginning_string(model)
      ending_string = ending_string(model)
      guid_symbol = guid_symbol(model)

      raise "Invalid duration model: #{model}" if beginning_string.nil? || ending_string.nil? || guid_symbol.nil?

      initial_records = old_records.where(state: beginning_string).from_self(alias: :initial_records)
      final_records = old_records.where(state: ending_string).from_self(alias: :final_records)

      exists_condition = final_records.where(Sequel[:final_records][guid_symbol] => Sequel[:initial_records][guid_symbol]).where do
        Sequel[:final_records][:id] > Sequel[:initial_records][:id]
      end.select(1).exists

      prunable_initial_records = initial_records.where(exists_condition)
      other_records = old_records.exclude(state: [beginning_string, ending_string])

      prunable_initial_records.union(final_records, all: true).union(other_records, all: true)
    end

    def has_duration?(model)
      return true if model == VCAP::CloudController::AppUsageEvent
      return true if model == VCAP::CloudController::ServiceUsageEvent

      false
    end

    def beginning_string(model)
      return VCAP::CloudController::ProcessModel::STARTED if model == VCAP::CloudController::AppUsageEvent
      return VCAP::CloudController::Repositories::ServiceUsageEventRepository::CREATED_EVENT_STATE if model == VCAP::CloudController::ServiceUsageEvent

      nil
    end

    def ending_string(model)
      return VCAP::CloudController::ProcessModel::STOPPED if model == VCAP::CloudController::AppUsageEvent
      return VCAP::CloudController::Repositories::ServiceUsageEventRepository::DELETED_EVENT_STATE if model == VCAP::CloudController::ServiceUsageEvent

      nil
    end

    def guid_symbol(model)
      return :app_guid if model == VCAP::CloudController::AppUsageEvent
      return :service_instance_guid if model == VCAP::CloudController::ServiceUsageEvent

      nil
    end
  end
end
