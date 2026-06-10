require 'spec_helper'
require 'database/old_record_cleanup'

# Lifecycle-aware cleanup behavior that is identical for app and service usage
# events. Expects the including context to define :model, :beginning_state,
# :ending_state and :guid_column.
RSpec.shared_examples 'usage event lifecycle cleanup' do
  def make_event(state, guid, created_at:)
    create(model.name.demodulize.underscore.to_sym, state: state, created_at: created_at, **{ guid_column => guid })
  end

  def run_cleanup(**opts)
    Database::OldRecordCleanup.new(model, cutoff_age_in_days: 1, keep_running_records: true, **opts).delete
  end

  it 'keeps an old beginning record when there is no corresponding ending record' do
    old_beginning = make_event(beginning_state, 'guid1', created_at: 2.days.ago)

    run_cleanup

    expect(old_beginning.reload).to be_present
    expect(model.count).to eq(1)
  end

  it 'keeps an old beginning record when the ending record is fresh' do
    old_beginning = make_event(beginning_state, 'guid1', created_at: 2.days.ago)
    fresh_ending = make_event(ending_state, 'guid1', created_at: 1.day.ago + 1.minute)

    run_cleanup

    expect(old_beginning.reload).to be_present
    expect(fresh_ending.reload).to be_present
  end

  it 'keeps an old beginning record when the ending record was inserted first' do
    old_ending = make_event(ending_state, 'guid1', created_at: 3.days.ago)
    old_beginning = make_event(beginning_state, 'guid1', created_at: 2.days.ago)

    run_cleanup

    expect(old_beginning.reload).to be_present
    expect { old_ending.reload }.to raise_error(Sequel::NoExistingObject)
  end

  it 'uses insertion order rather than created_at to pair beginnings with endings' do
    old_beginning = make_event(beginning_state, 'guid1', created_at: 2.days.ago)
    # Earlier timestamp but higher id: the resource is no longer running.
    old_ending = make_event(ending_state, 'guid1', created_at: 3.days.ago)

    run_cleanup

    expect { old_beginning.reload }.to raise_error(Sequel::NoExistingObject)
    expect { old_ending.reload }.to raise_error(Sequel::NoExistingObject)
  end

  it 'deletes all records of completed runs spanning multiple cycles' do
    cycle1_beginning = make_event(beginning_state, 'guid1', created_at: 10.days.ago)
    cycle1_ending = make_event(ending_state, 'guid1', created_at: 9.days.ago)
    cycle2_beginning = make_event(beginning_state, 'guid1', created_at: 8.days.ago)
    cycle2_ending = make_event(ending_state, 'guid1', created_at: 7.days.ago)

    run_cleanup

    expect { cycle1_beginning.reload }.to raise_error(Sequel::NoExistingObject)
    expect { cycle1_ending.reload }.to raise_error(Sequel::NoExistingObject)
    expect { cycle2_beginning.reload }.to raise_error(Sequel::NoExistingObject)
    expect { cycle2_ending.reload }.to raise_error(Sequel::NoExistingObject)
  end

  it 'deletes an old ending record that has no beginning record' do
    orphan_ending = make_event(ending_state, 'guid1', created_at: 10.days.ago)

    run_cleanup

    expect { orphan_ending.reload }.to raise_error(Sequel::NoExistingObject)
  end

  it 'keeps an old WAS_RUNNING record when there is no corresponding ending record' do
    was_running = make_event('WAS_RUNNING', 'guid1', created_at: 2.days.ago)

    run_cleanup

    expect(was_running.reload).to be_present
    expect(model.count).to eq(1)
  end

  it 'deletes an old WAS_RUNNING record when a later old ending record exists' do
    was_running = make_event('WAS_RUNNING', 'guid1', created_at: 5.days.ago)
    old_ending = make_event(ending_state, 'guid1', created_at: 4.days.ago)

    run_cleanup

    expect { was_running.reload }.to raise_error(Sequel::NoExistingObject)
    expect { old_ending.reload }.to raise_error(Sequel::NoExistingObject)
  end

  it 'keeps both the first beginning and a later WAS_RUNNING record of a running resource' do
    old_beginning = make_event(beginning_state, 'guid1', created_at: 10.days.ago)
    was_running = make_event('WAS_RUNNING', 'guid1', created_at: 5.days.ago)

    run_cleanup

    expect(old_beginning.reload).to be_present
    expect(was_running.reload).to be_present
  end

  it 'prunes superseded baselines of a running resource, keeping the first beginning (true start) and the latest one (current footprint)' do
    first = make_event(beginning_state, 'guid1', created_at: 5.days.ago)
    middle = make_event(beginning_state, 'guid1', created_at: 4.days.ago)
    latest = make_event(beginning_state, 'guid1', created_at: 3.days.ago)

    run_cleanup

    expect(first.reload).to be_present
    expect { middle.reload }.to raise_error(Sequel::NoExistingObject)
    expect(latest.reload).to be_present
  end

  it 'does not prune a superseded baseline until the beginning that supersedes it is itself old' do
    first = make_event(beginning_state, 'guid1', created_at: 5.days.ago)
    middle = make_event(beginning_state, 'guid1', created_at: 4.days.ago)
    fresh_latest = make_event(beginning_state, 'guid1', created_at: 1.day.ago + 1.minute)

    run_cleanup

    expect(first.reload).to be_present
    expect(middle.reload).to be_present
    expect(fresh_latest.reload).to be_present
  end

  it 'treats the first beginning after an ended run as the true start, not as a superseded baseline' do
    ended_run_beginning = make_event(beginning_state, 'guid1', created_at: 10.days.ago)
    ended_run_ending = make_event(ending_state, 'guid1', created_at: 9.days.ago)
    current_run_first = make_event(beginning_state, 'guid1', created_at: 8.days.ago)
    current_run_latest = make_event(beginning_state, 'guid1', created_at: 7.days.ago)

    run_cleanup

    expect { ended_run_beginning.reload }.to raise_error(Sequel::NoExistingObject)
    expect { ended_run_ending.reload }.to raise_error(Sequel::NoExistingObject)
    expect(current_run_first.reload).to be_present
    expect(current_run_latest.reload).to be_present
  end
end

RSpec.describe Database::OldRecordCleanup do
  describe '#delete' do
    let!(:stale_event1) { create(:event, created_at: 1.day.ago - 1.minute) }
    let!(:stale_event2) { create(:event, created_at: 2.days.ago) }

    let!(:fresh_event) { create(:event, created_at: 1.day.ago + 1.minute) }

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

    context 'when keep_running_records is requested for a model without usage lifecycles' do
      it 'raises rather than silently deleting the records of running resources' do
        record_cleanup = Database::OldRecordCleanup.new(VCAP::CloudController::Event, cutoff_age_in_days: 1, keep_running_records: true)

        expect { record_cleanup.delete }.to raise_error(ArgumentError, /usage_lifecycles/)
      end
    end

    describe 'keeping running AppUsageEvent records' do
      let(:model) { VCAP::CloudController::AppUsageEvent }
      let(:beginning_state) { 'STARTED' }
      let(:ending_state) { 'STOPPED' }
      let(:guid_column) { :app_guid }

      include_examples 'usage event lifecycle cleanup'

      describe 'task lifecycle' do
        it 'keeps the TASK_STARTED record of a still-running task' do
          task_started = create(model.name.demodulize.underscore.to_sym, created_at: 2.days.ago, state: 'TASK_STARTED', task_guid: 'task1', app_guid: 'app1')

          run_cleanup

          expect(task_started.reload).to be_present
        end

        it 'deletes the TASK_STARTED and TASK_STOPPED records of a completed task' do
          task_started = create(model.name.demodulize.underscore.to_sym, created_at: 5.days.ago, state: 'TASK_STARTED', task_guid: 'task1', app_guid: 'app1')
          task_stopped = create(model.name.demodulize.underscore.to_sym, created_at: 4.days.ago, state: 'TASK_STOPPED', task_guid: 'task1', app_guid: 'app1')

          run_cleanup

          expect { task_started.reload }.to raise_error(Sequel::NoExistingObject)
          expect { task_stopped.reload }.to raise_error(Sequel::NoExistingObject)
        end

        it 'keeps the TASK_STARTED record when the TASK_STOPPED record is fresh' do
          task_started = create(model.name.demodulize.underscore.to_sym, created_at: 2.days.ago, state: 'TASK_STARTED', task_guid: 'task1', app_guid: 'app1')
          fresh_task_stopped = create(model.name.demodulize.underscore.to_sym, created_at: 1.day.ago + 1.minute, state: 'TASK_STOPPED', task_guid: 'task1', app_guid: 'app1')

          run_cleanup

          expect(task_started.reload).to be_present
          expect(fresh_task_stopped.reload).to be_present
        end

        it 'correlates task records by task_guid, not by app_guid' do
          running_task_started = create(model.name.demodulize.underscore.to_sym, created_at: 5.days.ago, state: 'TASK_STARTED', task_guid: 'task1', app_guid: 'app1')
          other_task_stopped = create(model.name.demodulize.underscore.to_sym, created_at: 4.days.ago, state: 'TASK_STOPPED', task_guid: 'task2', app_guid: 'app1')

          run_cleanup

          expect(running_task_started.reload).to be_present
          expect { other_task_stopped.reload }.to raise_error(Sequel::NoExistingObject)
        end

        it 'keeps the TASK_WAS_RUNNING baseline of a still-running task' do
          baseline = create(model.name.demodulize.underscore.to_sym, created_at: 2.days.ago, state: 'TASK_WAS_RUNNING', task_guid: 'task1', app_guid: '')

          run_cleanup

          expect(baseline.reload).to be_present
        end

        it 'deletes the TASK_WAS_RUNNING baseline once a later TASK_STOPPED record is also old' do
          baseline = create(model.name.demodulize.underscore.to_sym, created_at: 5.days.ago, state: 'TASK_WAS_RUNNING', task_guid: 'task1', app_guid: '')
          task_stopped = create(model.name.demodulize.underscore.to_sym, created_at: 4.days.ago, state: 'TASK_STOPPED', task_guid: 'task1', app_guid: '')

          run_cleanup

          expect { baseline.reload }.to raise_error(Sequel::NoExistingObject)
          expect { task_stopped.reload }.to raise_error(Sequel::NoExistingObject)
        end

        # Task events carry an empty app_guid, so if task baselines shared the
        # WAS_RUNNING state they would all correlate with each other through the
        # app lifecycle (keyed by app_guid) and be wrongly pruned as superseded
        # baselines of one phantom app. The distinct TASK_WAS_RUNNING state keeps
        # the app lifecycle blind to them.
        it 'does not prune the baselines of distinct running tasks as superseded baselines of one phantom app' do
          baselines = %w[task1 task2 task3].each_with_index.map do |task_guid, i|
            create(model.name.demodulize.underscore.to_sym, created_at: (5 - i).days.ago, state: 'TASK_WAS_RUNNING', task_guid: task_guid, app_guid: '')
          end

          run_cleanup

          baselines.each { |baseline| expect(baseline.reload).to be_present }
        end
      end

      it 'deletes records with non-lifecycle states' do
        buildpack_event1 = create(model.name.demodulize.underscore.to_sym, created_at: 3.days.ago, state: 'BUILDPACK_SET', app_guid: 'app1')
        buildpack_event2 = create(model.name.demodulize.underscore.to_sym, created_at: 2.days.ago, state: 'BUILDPACK_SET', app_guid: 'app2')

        run_cleanup

        expect { buildpack_event1.reload }.to raise_error(Sequel::NoExistingObject)
        expect { buildpack_event2.reload }.to raise_error(Sequel::NoExistingObject)
      end

      it 'deletes old records with a corresponding stop record even if app_guid is an empty string' do
        empty_guid_start = create(model.name.demodulize.underscore.to_sym, created_at: 5.days.ago, state: 'STARTED', app_guid: '')
        different_empty_start = create(model.name.demodulize.underscore.to_sym, created_at: 4.days.ago, state: 'STARTED', app_guid: '')
        empty_guid_stop = create(model.name.demodulize.underscore.to_sym, created_at: 3.days.ago, state: 'STOPPED', app_guid: '')

        run_cleanup

        # Both STARTs with an empty-string guid have a STOP with an empty-string guid after them.
        expect { empty_guid_start.reload }.to raise_error(Sequel::NoExistingObject)
        expect { different_empty_start.reload }.to raise_error(Sequel::NoExistingObject)
        expect { empty_guid_stop.reload }.to raise_error(Sequel::NoExistingObject)
      end

      it 'works when cutoff_age_in_days is 0' do
        old_start = create(model.name.demodulize.underscore.to_sym, created_at: 1.second.ago, state: 'STARTED', app_guid: 'running-app')

        Database::OldRecordCleanup.new(model, cutoff_age_in_days: 0, keep_running_records: true).delete

        expect(old_start.reload).to be_present
      end

      it 'does not error if the table is empty' do
        model.dataset.delete

        expect { run_cleanup }.not_to raise_error
      end

      it 'deletes all old records when keep_running_records is false' do
        old_start = create(model.name.demodulize.underscore.to_sym, created_at: 5.days.ago, state: 'STARTED', app_guid: 'app1')
        old_stop = create(model.name.demodulize.underscore.to_sym, created_at: 4.days.ago, state: 'STOPPED', app_guid: 'app1')
        old_running_start = create(model.name.demodulize.underscore.to_sym, created_at: 3.days.ago, state: 'STARTED', app_guid: 'running-app')

        Database::OldRecordCleanup.new(model, cutoff_age_in_days: 1, keep_running_records: false).delete

        expect { old_start.reload }.to raise_error(Sequel::NoExistingObject)
        expect { old_stop.reload }.to raise_error(Sequel::NoExistingObject)
        expect { old_running_start.reload }.to raise_error(Sequel::NoExistingObject)
      end

      it 'keep_at_least_one_record preserves the last record while still pruning its paired START' do
        old_start = create(model.name.demodulize.underscore.to_sym, created_at: 10.days.ago, state: 'STARTED', app_guid: 'app1')
        last_stop = create(model.name.demodulize.underscore.to_sym, created_at: 9.days.ago, state: 'STOPPED', app_guid: 'app1')

        run_cleanup(keep_at_least_one_record: true)

        expect { old_start.reload }.to raise_error(Sequel::NoExistingObject) # paired with STOP, prunable
        expect(last_stop.reload).to be_present # kept by keep_at_least_one_record
      end

      it 'prunes a paired set larger than the delete batch size while keeping running records' do
        old = 5.days.ago

        # 1,500 completed START/STOP pairs (3,000 rows) -> well above the 1,000-row
        # batch size, so the delete spans multiple batches across the two passes.
        paired_rows = []
        1_500.times do |i|
          guid = "paired-#{i}"
          common = { app_name: guid, space_guid: 'sp', space_name: 'sp', org_guid: 'o',
                     instance_count: 1, memory_in_mb_per_instance: 1, created_at: old }
          paired_rows << common.merge(guid: "start-#{i}", state: 'STARTED', app_guid: guid)
          paired_rows << common.merge(guid: "stop-#{i}", state: 'STOPPED', app_guid: guid)
        end
        model.dataset.multi_insert(paired_rows)

        # Still-running apps (START with no later STOP) that must survive cleanup.
        running = Array.new(50) do |i|
          create(model.name.demodulize.underscore.to_sym, created_at: old, state: 'STARTED', app_guid: "running-#{i}")
        end

        run_cleanup

        # Every completed pair is gone; only the running records remain.
        running.each { |event| expect(event.reload).to be_present }
        expect(model.count).to eq(running.size)
      end
    end

    describe 'keeping running ServiceUsageEvent records' do
      let(:model) { VCAP::CloudController::ServiceUsageEvent }
      let(:beginning_state) { 'CREATED' }
      let(:ending_state) { 'DELETED' }
      let(:guid_column) { :service_instance_guid }

      include_examples 'usage event lifecycle cleanup'

      describe 'UPDATED records' do
        it 'keeps the CREATED record and the latest UPDATED record while the service instance exists, pruning superseded UPDATED records' do
          stale_created = create(model.name.demodulize.underscore.to_sym, created_at: 10.days.ago, state: 'CREATED', service_instance_guid: 'guid1')
          superseded_update = create(model.name.demodulize.underscore.to_sym, created_at: 8.days.ago, state: 'UPDATED', service_instance_guid: 'guid1')
          latest_update = create(model.name.demodulize.underscore.to_sym, created_at: 6.days.ago, state: 'UPDATED', service_instance_guid: 'guid1')

          run_cleanup

          expect(stale_created.reload).to be_present
          expect { superseded_update.reload }.to raise_error(Sequel::NoExistingObject)
          expect(latest_update.reload).to be_present
        end

        it 'keeps UPDATED records when the corresponding delete record is fresh' do
          stale_updated = create(model.name.demodulize.underscore.to_sym, created_at: 2.days.ago, state: 'UPDATED', service_instance_guid: 'guid1')
          fresh_delete = create(model.name.demodulize.underscore.to_sym, created_at: 1.day.ago + 1.minute, state: 'DELETED', service_instance_guid: 'guid1')

          run_cleanup

          expect(stale_updated.reload).to be_present
          expect(fresh_delete.reload).to be_present
        end

        it 'deletes UPDATED records when there is a corresponding old delete record' do
          stale_created = create(model.name.demodulize.underscore.to_sym, created_at: 10.days.ago, state: 'CREATED', service_instance_guid: 'guid1')
          stale_updated = create(model.name.demodulize.underscore.to_sym, created_at: 8.days.ago, state: 'UPDATED', service_instance_guid: 'guid1')
          stale_delete = create(model.name.demodulize.underscore.to_sym, created_at: 6.days.ago, state: 'DELETED', service_instance_guid: 'guid1')

          run_cleanup

          expect { stale_created.reload }.to raise_error(Sequel::NoExistingObject)
          expect { stale_updated.reload }.to raise_error(Sequel::NoExistingObject)
          expect { stale_delete.reload }.to raise_error(Sequel::NoExistingObject)
        end
      end
    end
  end
end
