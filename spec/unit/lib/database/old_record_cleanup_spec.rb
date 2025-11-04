require 'spec_helper'
require 'database/old_record_cleanup'

RSpec.describe Database::OldRecordCleanup do
  describe '#delete' do
    let!(:stale_event1) { VCAP::CloudController::Event.make(created_at: 1.day.ago - 1.minute) }
    let!(:stale_event2) { VCAP::CloudController::Event.make(created_at: 2.days.ago) }

    let!(:fresh_event) { VCAP::CloudController::Event.make(created_at: 1.day.ago + 1.minute) }

    # ==================== CORE FUNCTIONALITY ====================

    it 'deletes records older than specified days' do
      record_cleanup = Database::OldRecordCleanup.new(VCAP::CloudController::Event, cutoff_age_in_days: 1)

      expect do
        record_cleanup.delete
      end.to change(VCAP::CloudController::Event, :count).by(-2)

      expect(fresh_event.reload).to be_present
      expect { stale_event1.reload }.to raise_error(Sequel::NoExistingObject)
      expect { stale_event2.reload }.to raise_error(Sequel::NoExistingObject)
    end

    it 'only retrieves the current timestamp from the database once' do
      expect(VCAP::CloudController::Event.db).to receive(:fetch).with('SELECT CURRENT_TIMESTAMP as now').once.and_call_original
      record_cleanup = Database::OldRecordCleanup.new(VCAP::CloudController::Event, cutoff_age_in_days: 1)
      record_cleanup.delete
    end

    it 'keeps the last row when :keep_at_least_one_record is true even if it is older than the cutoff date' do
      record_cleanup = Database::OldRecordCleanup.new(VCAP::CloudController::Event, cutoff_age_in_days: 0, keep_at_least_one_record: true)

      expect do
        record_cleanup.delete
      end.to change(VCAP::CloudController::Event, :count).by(-2)

      expect(fresh_event.reload).to be_present
      expect { stale_event1.reload }.to raise_error(Sequel::NoExistingObject)
      expect { stale_event2.reload }.to raise_error(Sequel::NoExistingObject)
    end

    context "when there are no records at all but you're trying to keep at least one" do
      it "doesn't keep one because there aren't any to keep" do
        record_cleanup = Database::OldRecordCleanup.new(VCAP::CloudController::ServiceUsageEvent, cutoff_age_in_days: 1, keep_at_least_one_record: true)

        expect { record_cleanup.delete }.not_to raise_error
        expect(VCAP::CloudController::ServiceUsageEvent.count).to eq(0)
      end
    end

    # ==================== KEEP_RUNNING_RECORDS: AppUsageEvent ====================

    it 'keeps AppUsageEvent start record when there is no corresponding stop record' do
      stale_app_usage_event_start = VCAP::CloudController::AppUsageEvent.make(created_at: 2.days.ago, state: 'STARTED', app_guid: 'guid1')

      record_cleanup = Database::OldRecordCleanup.new(VCAP::CloudController::AppUsageEvent, cutoff_age_in_days: 1, keep_at_least_one_record: false, keep_running_records: true)
      record_cleanup.delete
      expect(stale_app_usage_event_start.reload).to be_present
      expect(VCAP::CloudController::AppUsageEvent.count).to eq(1)
    end

    it 'keeps AppUsageEvent start record when stop record is fresh' do
      stale_app_usage_event_start = VCAP::CloudController::AppUsageEvent.make(created_at: 2.days.ago, state: 'STARTED', app_guid: 'guid1')
      fresh_app_usage_event_stop = VCAP::CloudController::AppUsageEvent.make(created_at: 1.day.ago + 1.minute, state: 'STOPPED', app_guid: 'guid1')

      record_cleanup = Database::OldRecordCleanup.new(VCAP::CloudController::AppUsageEvent, cutoff_age_in_days: 1, keep_at_least_one_record: false, keep_running_records: true)
      record_cleanup.delete
      expect(stale_app_usage_event_start.reload).to be_present
      expect(fresh_app_usage_event_stop.reload).to be_present
    end

    it 'keeps AppUsageEvent start record when stop record was inserted first' do
      stale_app_usage_event_stop = VCAP::CloudController::AppUsageEvent.make(created_at: 3.days.ago, state: 'STOPPED', app_guid: 'guid1')
      stale_app_usage_event_start = VCAP::CloudController::AppUsageEvent.make(created_at: 2.days.ago, state: 'STARTED', app_guid: 'guid1')

      record_cleanup = Database::OldRecordCleanup.new(VCAP::CloudController::AppUsageEvent, cutoff_age_in_days: 1, keep_at_least_one_record: false, keep_running_records: true)
      record_cleanup.delete
      expect(stale_app_usage_event_start.reload).to be_present
      expect { stale_app_usage_event_stop.reload }.to raise_error(Sequel::NoExistingObject)
    end

    it 'deletes old AppUsageEvent records when they have a corresponding stop record' do
      app_guid = 'app-with-multiple-cycles'

      cycle1_start = VCAP::CloudController::AppUsageEvent.make(created_at: 10.days.ago, state: 'STARTED', app_guid: app_guid)
      cycle1_stop = VCAP::CloudController::AppUsageEvent.make(created_at: 9.days.ago, state: 'STOPPED', app_guid: app_guid)

      cycle2_start = VCAP::CloudController::AppUsageEvent.make(created_at: 8.days.ago, state: 'STARTED', app_guid: app_guid)
      cycle2_stop = VCAP::CloudController::AppUsageEvent.make(created_at: 7.days.ago, state: 'STOPPED', app_guid: app_guid)

      record_cleanup = Database::OldRecordCleanup.new(VCAP::CloudController::AppUsageEvent, cutoff_age_in_days: 1, keep_at_least_one_record: false, keep_running_records: true)
      record_cleanup.delete

      expect { cycle1_start.reload }.to raise_error(Sequel::NoExistingObject)
      expect { cycle1_stop.reload }.to raise_error(Sequel::NoExistingObject)
      expect { cycle2_start.reload }.to raise_error(Sequel::NoExistingObject)
      expect { cycle2_stop.reload }.to raise_error(Sequel::NoExistingObject)
    end

    it 'deletes a single old AppUsageEvent stop record with no start record' do
      single_stop = VCAP::CloudController::AppUsageEvent.make(created_at: 10.days.ago, state: 'STOPPED', app_guid: 'stopped-app')

      record_cleanup = Database::OldRecordCleanup.new(VCAP::CloudController::AppUsageEvent, cutoff_age_in_days: 1, keep_at_least_one_record: false, keep_running_records: true)
      record_cleanup.delete

      expect { single_stop.reload }.to raise_error(Sequel::NoExistingObject)
      expect(VCAP::CloudController::AppUsageEvent.count).to eq(0)
    end

    # ==================== KEEP_RUNNING_RECORDS: ServiceUsageEvent ====================

    it 'keeps ServiceUsageEvent create record when there is no corresponding delete record' do
      stale_service_usage_event_create = VCAP::CloudController::ServiceUsageEvent.make(created_at: 2.days.ago, state: 'CREATED', service_instance_guid: 'guid1')

      record_cleanup = Database::OldRecordCleanup.new(VCAP::CloudController::ServiceUsageEvent, cutoff_age_in_days: 1, keep_at_least_one_record: false, keep_running_records: true)
      record_cleanup.delete
      expect(stale_service_usage_event_create.reload).to be_present
      expect(VCAP::CloudController::ServiceUsageEvent.count).to eq(1)
    end

    it 'keeps ServiceUsageEvent create record when delete record is fresh' do
      stale_service_usage_event_create = VCAP::CloudController::ServiceUsageEvent.make(created_at: 2.days.ago, state: 'CREATED', service_instance_guid: 'guid1')
      fresh_service_usage_event_delete = VCAP::CloudController::ServiceUsageEvent.make(created_at: 1.day.ago + 1.minute, state: 'DELETED', service_instance_guid: 'guid1')

      record_cleanup = Database::OldRecordCleanup.new(VCAP::CloudController::ServiceUsageEvent, cutoff_age_in_days: 1, keep_at_least_one_record: false, keep_running_records: true)
      record_cleanup.delete
      expect(stale_service_usage_event_create.reload).to be_present
      expect(fresh_service_usage_event_delete.reload).to be_present
    end

    it 'keeps ServiceUsageEvent create record when delete record was inserted first' do
      stale_service_usage_event_delete = VCAP::CloudController::ServiceUsageEvent.make(created_at: 3.days.ago, state: 'DELETED', service_instance_guid: 'guid1')
      stale_service_usage_event_create = VCAP::CloudController::ServiceUsageEvent.make(created_at: 2.days.ago, state: 'CREATED', service_instance_guid: 'guid1')

      record_cleanup = Database::OldRecordCleanup.new(VCAP::CloudController::ServiceUsageEvent, cutoff_age_in_days: 1, keep_at_least_one_record: false, keep_running_records: true)
      record_cleanup.delete
      expect(stale_service_usage_event_create.reload).to be_present
      expect { stale_service_usage_event_delete.reload }.to raise_error(Sequel::NoExistingObject)
    end

    it 'keeps all ServiceUsageEvent created records when there is no corresponding deleted record' do
      service_guid = 'multi-create-service'

      create1 = VCAP::CloudController::ServiceUsageEvent.make(created_at: 10.days.ago, state: 'CREATED', service_instance_guid: service_guid)
      create2 = VCAP::CloudController::ServiceUsageEvent.make(created_at: 8.days.ago, state: 'CREATED', service_instance_guid: service_guid)
      create3 = VCAP::CloudController::ServiceUsageEvent.make(created_at: 6.days.ago, state: 'CREATED', service_instance_guid: service_guid)

      record_cleanup = Database::OldRecordCleanup.new(
        VCAP::CloudController::ServiceUsageEvent,
        cutoff_age_in_days: 1,
        keep_running_records: true
      )
      record_cleanup.delete

      expect(create1.reload).to be_present
      expect(create2.reload).to be_present
      expect(create3.reload).to be_present
    end

    it 'deletes ServiceUsageEvent deleted records without a create' do
      service_guid = 'orphan-delete-service'

      orphan_delete = VCAP::CloudController::ServiceUsageEvent.make(
        created_at: 10.days.ago,
        state: 'DELETED',
        service_instance_guid: service_guid
      )

      record_cleanup = Database::OldRecordCleanup.new(
        VCAP::CloudController::ServiceUsageEvent,
        cutoff_age_in_days: 1,
        keep_running_records: true
      )
      record_cleanup.delete

      expect { orphan_delete.reload }.to raise_error(Sequel::NoExistingObject)
    end

    # ==================== EDGE CASES & DATA INTEGRITY ====================

    it 'deletes records with non-lifecycle states when keep_running_records is true' do
      # Create records with various states, all old
      buildpack_event1 = VCAP::CloudController::AppUsageEvent.make(created_at: 3.days.ago, state: 'BUILDPACK_SET', app_guid: 'app1')
      buildpack_event2 = VCAP::CloudController::AppUsageEvent.make(created_at: 2.days.ago, state: 'BUILDPACK_SET', app_guid: 'app2')
      task_event = VCAP::CloudController::AppUsageEvent.make(created_at: 2.days.ago, state: 'TASK_STOPPED', app_guid: 'app3')

      record_cleanup = Database::OldRecordCleanup.new(VCAP::CloudController::AppUsageEvent, cutoff_age_in_days: 1, keep_at_least_one_record: false, keep_running_records: true)
      record_cleanup.delete

      expect { buildpack_event1.reload }.to raise_error(Sequel::NoExistingObject)
      expect { buildpack_event2.reload }.to raise_error(Sequel::NoExistingObject)
      expect { task_event.reload }.to raise_error(Sequel::NoExistingObject)
    end

    it 'deletes AppUsageEvent records when stop record created before start record' do
      app_guid = 'time-travel-app'

      start_event = VCAP::CloudController::AppUsageEvent.make(
        created_at: 2.days.ago,
        state: 'STARTED',
        app_guid: app_guid
      )

      stop_event = VCAP::CloudController::AppUsageEvent.make(
        created_at: 3.days.ago, # Earlier timestamp but higher ID
        state: 'STOPPED',
        app_guid: app_guid
      )

      record_cleanup = Database::OldRecordCleanup.new(
        VCAP::CloudController::AppUsageEvent,
        cutoff_age_in_days: 1,
        keep_running_records: true
      )
      record_cleanup.delete

      expect { start_event.reload }.to raise_error(Sequel::NoExistingObject)
      expect { stop_event.reload }.to raise_error(Sequel::NoExistingObject)
    end

    it 'keeps multiple AppUsageEvent start records when there is no stop record' do
      app_guid = 'multi-start-app'

      # Multiple START events for same app
      start1 = VCAP::CloudController::AppUsageEvent.make(created_at: 5.days.ago, state: 'STARTED', app_guid: app_guid)
      start2 = VCAP::CloudController::AppUsageEvent.make(created_at: 4.days.ago, state: 'STARTED', app_guid: app_guid)
      start3 = VCAP::CloudController::AppUsageEvent.make(created_at: 3.days.ago, state: 'STARTED', app_guid: app_guid)

      record_cleanup = Database::OldRecordCleanup.new(
        VCAP::CloudController::AppUsageEvent,
        cutoff_age_in_days: 1,
        keep_running_records: true
      )
      record_cleanup.delete

      expect(start1.reload).to be_present
      expect(start2.reload).to be_present
      expect(start3.reload).to be_present
    end

    it 'deletes multiple AppUsageEvent stop records for the same app when there is only a single start' do
      app_guid = 'multi-stop-app'

      start_event = VCAP::CloudController::AppUsageEvent.make(created_at: 5.days.ago, state: 'STARTED', app_guid: app_guid)
      stop1 = VCAP::CloudController::AppUsageEvent.make(created_at: 4.days.ago, state: 'STOPPED', app_guid: app_guid)
      stop2 = VCAP::CloudController::AppUsageEvent.make(created_at: 3.days.ago, state: 'STOPPED', app_guid: app_guid)
      stop3 = VCAP::CloudController::AppUsageEvent.make(created_at: 2.days.ago, state: 'STOPPED', app_guid: app_guid)

      record_cleanup = Database::OldRecordCleanup.new(
        VCAP::CloudController::AppUsageEvent,
        cutoff_age_in_days: 1,
        keep_running_records: true
      )
      record_cleanup.delete

      # START has a STOP after it, so it should be deleted
      expect { start_event.reload }.to raise_error(Sequel::NoExistingObject)

      # All STOPs should be deleted
      expect { stop1.reload }.to raise_error(Sequel::NoExistingObject)
      expect { stop2.reload }.to raise_error(Sequel::NoExistingObject)
      expect { stop3.reload }.to raise_error(Sequel::NoExistingObject)
    end

    it 'deletes old AppUsageEvent records with corresponding stop record even if app_guid is an empty string' do
      empty_guid_start = VCAP::CloudController::AppUsageEvent.make(created_at: 5.days.ago, state: 'STARTED', app_guid: '')
      different_empty_start = VCAP::CloudController::AppUsageEvent.make(created_at: 4.days.ago, state: 'STARTED', app_guid: '')
      empty_guid_stop = VCAP::CloudController::AppUsageEvent.make(created_at: 3.days.ago, state: 'STOPPED', app_guid: '')

      record_cleanup = Database::OldRecordCleanup.new(
        VCAP::CloudController::AppUsageEvent,
        cutoff_age_in_days: 1,
        keep_running_records: true
      )
      record_cleanup.delete

      # Both STARTs with empty string have a STOP with empty string after them
      expect { empty_guid_start.reload }.to raise_error(Sequel::NoExistingObject)
      expect { different_empty_start.reload }.to raise_error(Sequel::NoExistingObject)
      expect { empty_guid_stop.reload }.to raise_error(Sequel::NoExistingObject)
    end

    it 'works when cutoff_age_in_days in 0' do
      old_start = VCAP::CloudController::AppUsageEvent.make(
        created_at: 1.second.ago,
        state: 'STARTED',
        app_guid: 'running-app'
      )

      record_cleanup = Database::OldRecordCleanup.new(
        VCAP::CloudController::AppUsageEvent,
        cutoff_age_in_days: 0,
        keep_running_records: true
      )
      record_cleanup.delete

      expect(old_start.reload).to be_present
    end

    it 'does not error if database is empty' do
      VCAP::CloudController::AppUsageEvent.dataset.delete

      record_cleanup = Database::OldRecordCleanup.new(
        VCAP::CloudController::AppUsageEvent,
        cutoff_age_in_days: 1,
        keep_running_records: true
      )

      expect { record_cleanup.delete }.not_to raise_error
    end

    # ==================== FEATURE FLAG COMBINATIONS ====================

    it 'deletes all old AppUsageEvent records when keep_running_records is false' do
      app_guid = 'no-keep-running-app'

      old_start = VCAP::CloudController::AppUsageEvent.make(created_at: 5.days.ago, state: 'STARTED', app_guid: app_guid)
      old_stop = VCAP::CloudController::AppUsageEvent.make(created_at: 4.days.ago, state: 'STOPPED', app_guid: app_guid)
      old_running_start = VCAP::CloudController::AppUsageEvent.make(created_at: 3.days.ago, state: 'STARTED', app_guid: 'running-app')

      record_cleanup = Database::OldRecordCleanup.new(
        VCAP::CloudController::AppUsageEvent,
        cutoff_age_in_days: 1,
        keep_running_records: false # Feature disabled
      )
      record_cleanup.delete

      # All old records deleted, including running app START
      expect { old_start.reload }.to raise_error(Sequel::NoExistingObject)
      expect { old_stop.reload }.to raise_error(Sequel::NoExistingObject)
      expect { old_running_start.reload }.to raise_error(Sequel::NoExistingObject)
    end

    it 'keep_at_least_one_record preserves last record even if it has a stop' do
      app_guid = 'last-record-stopped-app'

      old_start = VCAP::CloudController::AppUsageEvent.make(created_at: 10.days.ago, state: 'STARTED', app_guid: app_guid)
      last_stop = VCAP::CloudController::AppUsageEvent.make(created_at: 9.days.ago, state: 'STOPPED', app_guid: app_guid)

      record_cleanup = Database::OldRecordCleanup.new(
        VCAP::CloudController::AppUsageEvent,
        cutoff_age_in_days: 1,
        keep_at_least_one_record: true,
        keep_running_records: true
      )
      record_cleanup.delete

      # keep_at_least_one_record is applied BEFORE keep_running_records
      # So the last record (STOP) is excluded from deletion
      # Then keep_running_records logic runs on the remaining old_records
      # The START has a STOP with higher ID, but that STOP was excluded from old_records
      # So the START doesn't find a matching STOP in the old_records dataset and is kept
      expect(old_start.reload).to be_present  # Kept - no STOP in old_records to match
      expect(last_stop.reload).to be_present  # Kept - last record
    end
  end
end
