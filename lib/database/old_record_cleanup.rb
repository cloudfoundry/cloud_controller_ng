require 'database/batch_delete'

module Database
  class OldRecordCleanup
    class NoCurrentTimestampError < StandardError; end
    attr_reader :model, :days_ago, :keep_at_least_one_record, :keep_running_records, :keep_unprocessed_records, :threshold_for_keeping_unprocessed_records

    def initialize(model, cutoff_age_in_days:, keep_at_least_one_record: false, keep_running_records: false, keep_unprocessed_records: false,
                   threshold_for_keeping_unprocessed_records: nil)
      @model = model
      @days_ago = cutoff_age_in_days
      @keep_at_least_one_record = keep_at_least_one_record
      @keep_running_records = keep_running_records
      @keep_unprocessed_records = keep_unprocessed_records
      @threshold_for_keeping_unprocessed_records = threshold_for_keeping_unprocessed_records
    end

    def delete
      cutoff_date = current_timestamp_from_database - days_ago.to_i.days

      old_records = model.dataset.where(Sequel.lit('created_at < ?', cutoff_date))
      if keep_at_least_one_record
        last_record = model.order(:id).last
        old_records = old_records.where(Sequel.lit('id < ?', last_record.id)) if last_record
      end

      old_records = exclude_running_records(old_records) if keep_running_records
      old_records = exclude_unprocessed_records(old_records) if keep_unprocessed_records

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

    def exclude_unprocessed_records(old_records)
      consumer_model = registered_consumer_model(model)

      return old_records unless consumer_model

      if approximate_row_count(model) < threshold_for_keeping_unprocessed_records.to_i
        # Find the usage event record with the lowest ID
        # of any that are referenced by a consumer
        referenced_event = model.
                           join(consumer_model.table_name.to_sym, last_processed_guid: :guid).
                           select(Sequel.function(:min, Sequel.qualify(model.table_name, :id)).as(:min_id)).
                           first

        return old_records if referenced_event[:min_id].nil?

        old_records.where { id < referenced_event[:min_id] }
      else
        # When above threshold, we don't exclude any records
        # Associated consumers will be automatically deleted by Sequel
        old_records
      end
    end

    def registered_consumer_model(model)
      return VCAP::CloudController::AppUsageConsumer if model == VCAP::CloudController::AppUsageEvent && VCAP::CloudController::AppUsageConsumer.present?

      return VCAP::CloudController::ServiceUsageConsumer if model == VCAP::CloudController::ServiceUsageEvent && VCAP::CloudController::ServiceUsageConsumer.present?

      false
    end

    def approximate_row_count(model)
      case model.db.database_type
      when :postgres
        result = model.db[<<-SQL.squish
          SELECT reltuples::bigint AS estimate
          FROM pg_class
          WHERE relname = '#{model.table_name}'
        SQL
        ].first
        result[:estimate].to_i
      when :mysql, :mysql2
        result = model.db[<<-SQL.squish
          SELECT table_rows
          FROM information_schema.tables
          WHERE table_schema = DATABASE()
            AND table_name = '#{model.table_name}'
        SQL
        ].first
        result[:table_rows].to_i
      end
    end
  end
end
