require 'spec_helper'
require 'database/old_record_cleanup'

RSpec.describe Database::OldRecordCleanup do
  describe '#delete' do
    context ':keep_running_app_records is false (default)' do
      let!(:stale_event1) { VCAP::CloudController::Event.make(created_at: 1.day.ago - 1.minute) }
      let!(:stale_event2) { VCAP::CloudController::Event.make(created_at: 2.days.ago) }

      let!(:fresh_event) { VCAP::CloudController::Event.make(created_at: 1.day.ago + 1.minutes) }

      it 'deletes records older than specified days' do
        record_cleanup = Database::OldRecordCleanup.new(VCAP::CloudController::Event, 1)

        expect {
          record_cleanup.delete
        }.to change { VCAP::CloudController::Event.count }.by(-2)

        expect(fresh_event.reload).to be_present
        expect { stale_event1.reload }.to raise_error(Sequel::NoExistingObject)
        expect { stale_event2.reload }.to raise_error(Sequel::NoExistingObject)
      end

      it 'only retrieves the current timestamp from the database once' do
        expect(VCAP::CloudController::Event.db).to receive(:fetch).with('SELECT CURRENT_TIMESTAMP as now').once.and_call_original
        record_cleanup = Database::OldRecordCleanup.new(VCAP::CloudController::Event, 1)
        record_cleanup.delete
      end

      it 'keeps the last row when :keep_at_least_one_record is true even if it is older than the cutoff date' do
        record_cleanup = Database::OldRecordCleanup.new(VCAP::CloudController::Event, 0, keep_at_least_one_record: true)

        expect {
          record_cleanup.delete
        }.to change { VCAP::CloudController::Event.count }.by(-2)

        expect(fresh_event.reload).to be_present
        expect { stale_event1.reload }.to raise_error(Sequel::NoExistingObject)
        expect { stale_event2.reload }.to raise_error(Sequel::NoExistingObject)
      end
    end

    context ':keep_running_app_records is true' do
      START_STATE = 'STARTED'.freeze
      STOP_STATE = 'STOPPED'.freeze

      let!(:start_event_of_running_app) { VCAP::CloudController::AppUsageEvent.make(app_guid: 'app-guid-1', state: START_STATE, created_at: 3.days.ago) }

      let!(:stale_start_event_of_app_2) { VCAP::CloudController::AppUsageEvent.make(app_guid: 'app-guid-2', state: START_STATE, created_at: 3.days.ago) }
      let!(:fresh_stop_event_of_app_2) { VCAP::CloudController::AppUsageEvent.make(app_guid: 'app-guid-2', state: STOP_STATE, created_at: 1.minute.ago) }

      let!(:stale_start_event_of_app_3) { VCAP::CloudController::AppUsageEvent.make(app_guid: 'app-guid-3', state: START_STATE, created_at: 3.days.ago) }
      let!(:stale_stop_event_of_app_3) { VCAP::CloudController::AppUsageEvent.make(app_guid: 'app-guid-3', state: STOP_STATE, created_at: 2.days.ago) }

      it 'does not prune records of running apps when :keep_running_app_records is true even if it is older than cutoff date' do
        record_cleanup = Database::OldRecordCleanup.new(VCAP::CloudController::AppUsageEvent, 1, keep_running_app_records: true)

        expect {
          record_cleanup.delete
        }.to change { VCAP::CloudController::AppUsageEvent.count }.by(-2)

        expect(start_event_of_running_app.reload).to be_present
        expect(stale_start_event_of_app_2.reload).to be_present
        expect(fresh_stop_event_of_app_2.reload).to be_present

        expect { stale_start_event_of_app_3.reload }.to raise_error(Sequel::NoExistingObject)
        expect { stale_stop_event_of_app_3.reload }.to raise_error(Sequel::NoExistingObject)
      end
    end
  end
end
