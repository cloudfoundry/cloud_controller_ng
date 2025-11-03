require 'spec_helper'
require 'database/old_record_cleanup'

RSpec.describe Database::OldRecordCleanup do
  describe '#delete' do
    let!(:stale_event1) { VCAP::CloudController::Event.make(created_at: 1.day.ago - 1.minute) }
    let!(:stale_event2) { VCAP::CloudController::Event.make(created_at: 2.days.ago) }

    let!(:fresh_event) { VCAP::CloudController::Event.make(created_at: 1.day.ago + 1.minute) }

    it 'deletes records older than specified days' do
      record_cleanup = Database::OldRecordCleanup.new(VCAP::CloudController::Event, cutoff_age_in_days: 1)

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
  end
end
