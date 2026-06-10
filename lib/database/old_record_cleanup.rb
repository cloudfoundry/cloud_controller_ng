require 'database/batch_delete'

module Database
  class OldRecordCleanup
    class NoCurrentTimestampError < StandardError; end
    attr_reader :model, :cutoff_age_in_days, :keep_at_least_one_record, :keep_running_records

    def initialize(model, cutoff_age_in_days:, keep_at_least_one_record: false, keep_running_records: false)
      @model = model
      @cutoff_age_in_days = cutoff_age_in_days
      @keep_at_least_one_record = keep_at_least_one_record
      @keep_running_records = keep_running_records
    end

    # keep_running_records and keep_at_least_one_record compose: a still-running
    # resource (a beginning-state event with no later ending-state event for the
    # same resource) is always retained, and keep_at_least_one_record additionally
    # protects the single newest row so the table is never fully emptied for
    # clients that poll the most recent event.
    def delete
      cutoff_date = current_timestamp_from_database - cutoff_age_in_days.to_i.days
      old_records = model.dataset.where(Sequel.lit('created_at < ?', cutoff_date))

      if keep_running_records
        raise ArgumentError.new("keep_running_records requires #{model} to define .usage_lifecycles") unless model.respond_to?(:usage_lifecycles)

        delete_keeping_running_records(old_records)
      else
        old_records = exclude_newest_record(old_records)
        logger.info("Cleaning up #{old_records.count} #{model.table_name} table rows")
        Database::BatchDelete.new(old_records, 1000).delete
      end
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

    # Deletes old records while retaining a usable billing baseline for
    # still-running resources.
    #
    # For each lifecycle of the model, a beginning-state row (e.g.
    # STARTED/CREATED/WAS_RUNNING) is prunable when:
    # * a later ending-state row (e.g. STOPPED/DELETED) is also old -- the run is
    #   over; or
    # * it is a superseded baseline: an earlier beginning of the same run and a
    #   later beginning both exist (and are old). Consumers only need the first
    #   beginning of the current run (the true start time) and the latest one (the
    #   current footprint); the in-between rows written by scaling/updating a
    #   running resource carry no baseline information.
    #
    # The deletes are ordered deliberately: prunable beginning rows are removed
    # FIRST, while the rows that make them prunable still exist, so each beginning
    # stays prunable until it is itself deleted. Only then are the ending rows (and
    # any other, non-lifecycle states) removed. Reversing the order could strand a
    # beginning row whose paired ending was deleted in an earlier batch.
    def delete_keeping_running_records(old_records)
      lifecycles = model.usage_lifecycles
      prunable_beginnings = lifecycles.map { |lifecycle| prunable_beginnings_dataset(old_records, lifecycle) }

      # Everything that is not a beginning-state row of some lifecycle (ending rows
      # plus any other, non-lifecycle states) is unconditionally prunable.
      all_beginning_states = lifecycles.flat_map { |lifecycle| lifecycle.fetch(:beginning_states) }
      unconditional_records = exclude_newest_record(old_records.exclude(state: all_beginning_states))

      deleted_count = prunable_beginnings.sum { |dataset| Database::BatchDelete.new(dataset, 1000).delete }
      deleted_count += Database::BatchDelete.new(unconditional_records, 1000).delete

      logger.info("Cleaned up #{deleted_count} #{model.table_name} table rows")
    end

    # Builds the dataset of old beginning-state rows that are prunable for one
    # lifecycle. All correlations use the (state, guid, id) lifecycle index; higher
    # id implies later creation throughout. The probes only consider OLD rows: a
    # superseded beginning is kept until the row superseding it is itself old,
    # which keeps the pruning decision stable for consumers reading within the
    # retention window.
    def prunable_beginnings_dataset(old_records, lifecycle)
      beginning_states = lifecycle.fetch(:beginning_states)
      ending_state = lifecycle.fetch(:ending_state)
      guid_column = lifecycle.fetch(:guid_column)

      old_beginnings = old_records.where(state: beginning_states)
      old_endings = old_records.where(state: ending_state)
      initial_records = old_beginnings.from_self(alias: :initial_records)

      # The run is over: an ending row for the same resource was created later.
      matching_ending = old_endings.from_self(alias: :final_records).
                        where(Sequel[:final_records][guid_column] => Sequel[:initial_records][guid_column]).
                        where { Sequel[:final_records][:id] > Sequel[:initial_records][:id] }.
                        select(1).exists

      # Not the run's true start: an earlier beginning of the same run exists,
      # i.e. one with no ending event between the two.
      intervening_ending = old_endings.from_self(alias: :intervening_endings).
                           where(Sequel[:intervening_endings][guid_column] => Sequel[:earlier_beginnings][guid_column]).
                           where { Sequel[:intervening_endings][:id] > Sequel[:earlier_beginnings][:id] }.
                           where { Sequel[:intervening_endings][:id] < Sequel[:initial_records][:id] }.
                           select(1).exists
      earlier_beginning_in_same_run = old_beginnings.from_self(alias: :earlier_beginnings).
                                      where(Sequel[:earlier_beginnings][guid_column] => Sequel[:initial_records][guid_column]).
                                      where { Sequel[:earlier_beginnings][:id] < Sequel[:initial_records][:id] }.
                                      where(Sequel.~(intervening_ending)).
                                      select(1).exists

      # Not the latest baseline: a later beginning for the same resource exists.
      later_beginning = old_beginnings.from_self(alias: :later_beginnings).
                        where(Sequel[:later_beginnings][guid_column] => Sequel[:initial_records][guid_column]).
                        where { Sequel[:later_beginnings][:id] > Sequel[:initial_records][:id] }.
                        select(1).exists

      superseded_baseline = Sequel.&(earlier_beginning_in_same_run, later_beginning)
      exclude_newest_record(initial_records.where(Sequel.|(matching_ending, superseded_baseline)))
    end

    # When keep_at_least_one_record is set, never delete the single newest row so
    # the table always retains at least one record.
    def exclude_newest_record(records)
      return records unless keep_at_least_one_record && newest_record_id

      records.where(Sequel.lit('id < ?', newest_record_id))
    end

    def newest_record_id
      return @newest_record_id if defined?(@newest_record_id)

      @newest_record_id = model.order(:id).last&.id
    end
  end
end
