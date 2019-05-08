require 'spec_helper'
require 'database/old_record_cleanup'

RSpec.describe Database::OldRecordCleanup do
  describe '#delete' do
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
  end
end
