require 'spec_helper'
require 'database/was_running_backfill'

RSpec.describe VCAP::WasRunningBackfill do
  let(:db) { Sequel::Model.db }
  let(:logger) { double(Steno::Logger, info: nil) }

  def was_running
    db[:service_usage_events].where(state: 'WAS_RUNNING')
  end

  def app_was_running
    db[:app_usage_events].where(state: 'WAS_RUNNING')
  end

  def task_was_running
    db[:app_usage_events].where(state: 'TASK_WAS_RUNNING')
  end

  # The backfill exists for resources whose real start events were already
  # pruned by the events cleanup. The test factories, though, write those
  # events (a STARTED row when making a started process, a CREATED row when
  # making a service instance), and the seed guards deliberately skip resources
  # that have them. So tests that expect a resource to be seeded first delete
  # its events, putting it in the same state as a resource pruned in the wild.
  def prune_usage_events!
    db[:app_usage_events].delete
    db[:service_usage_events].delete
  end

  describe 'usage event state literals' do
    # The backfill is raw SQL (no CC code), so it can't reference the model and
    # repository constants directly. This guard catches any drift between the
    # literals the backfill writes/probes and the state values the
    # repositories/cleanup recognise.
    it 'match the state values used by the models and repositories' do
      expect(described_class::WAS_RUNNING).to eq(VCAP::CloudController::Repositories::AppUsageEventRepository::WAS_RUNNING_EVENT_STATE)
      expect(described_class::WAS_RUNNING).to eq(VCAP::CloudController::Repositories::ServiceUsageEventRepository::WAS_RUNNING_EVENT_STATE)
      expect(described_class::TASK_WAS_RUNNING).to eq(VCAP::CloudController::Repositories::AppUsageEventRepository::TASK_WAS_RUNNING_EVENT_STATE)
      expect(described_class::STARTED).to eq(VCAP::CloudController::ProcessModel::STARTED)
      expect(described_class::STOPPED).to eq(VCAP::CloudController::ProcessModel::STOPPED)
      expect(described_class::TASK_STARTED).to eq(VCAP::CloudController::Repositories::AppUsageEventRepository::TASK_STARTED_EVENT_STATE)
      expect(described_class::TASK_STOPPED).to eq(VCAP::CloudController::Repositories::AppUsageEventRepository::TASK_STOPPED_EVENT_STATE)
      expect(described_class::CREATED).to eq(VCAP::CloudController::Repositories::ServiceUsageEventRepository::CREATED_EVENT_STATE)
      expect(described_class::UPDATED).to eq(VCAP::CloudController::Repositories::ServiceUsageEventRepository::UPDATED_EVENT_STATE)
      expect(described_class::DELETED).to eq(VCAP::CloudController::Repositories::ServiceUsageEventRepository::DELETED_EVENT_STATE)
      expect(described_class::RUNNING_TASK_STATES).to contain_exactly(VCAP::CloudController::TaskModel::RUNNING_STATE,
                                                                      VCAP::CloudController::TaskModel::CANCELING_STATE)
    end
  end

  describe '.skip?' do
    let(:skip_was_running_backfill) { nil }

    before do
      allow_any_instance_of(VCAP::CloudController::Config).to receive(:get).with(:skip_was_running_backfill).and_return(skip_was_running_backfill)
    end

    context 'when skip_was_running_backfill is false' do
      let(:skip_was_running_backfill) { false }

      it 'returns false' do
        expect(described_class.skip?).to be(false)
      end
    end

    context 'when skip_was_running_backfill is true' do
      let(:skip_was_running_backfill) { true }

      it 'returns true' do
        expect(described_class.skip?).to be(true)
      end
    end

    context 'when skip_was_running_backfill is nil' do
      let(:skip_was_running_backfill) { nil }

      it 'returns false' do
        expect(described_class.skip?).to be(false)
      end
    end

    context 'when reading the config raises InvalidConfigPath' do
      before do
        allow_any_instance_of(VCAP::CloudController::Config).to receive(:get).with(:skip_was_running_backfill).and_raise(VCAP::CloudController::Config::InvalidConfigPath)
      end

      it 'returns false rather than aborting the migration' do
        expect(described_class.skip?).to be(false)
      end
    end
  end

  describe '.with_advisory_lock' do
    it 'runs the block and releases the lock for subsequent runs' do
      order = []
      described_class.with_advisory_lock(db) { order << :first }
      described_class.with_advisory_lock(db) { order << :second }
      expect(order).to eq(%i[first second])
    end

    it 'raises without running the block when another session already holds the lock' do
      other_db = Sequel.connect(DbConfig.new.connection_string)
      begin
        described_class.with_advisory_lock(other_db) do
          expect { described_class.with_advisory_lock(db) { raise 'the block must not run' } }.
            to raise_error(/another WAS_RUNNING backfill is already running/)
        end
      ensure
        other_db.disconnect
      end
    end

    it 'releases the lock when the block raises' do
      expect { described_class.with_advisory_lock(db) { raise ArgumentError.new('boom') } }.to raise_error(ArgumentError, 'boom')
      expect { |b| described_class.with_advisory_lock(db, &b) }.to yield_control
    end

    it 'with wait: true, waits for the holder to release instead of raising (the seed migrations use this)' do
      other_db = Sequel.connect(DbConfig.new.connection_string)
      begin
        order = []
        waiter = nil
        described_class.with_advisory_lock(other_db) do
          waiter = Thread.new do
            described_class.with_advisory_lock(db, wait: true) { order << :waiter_ran }
          end
          # Give the waiter time to reach (and block on) the lock acquire. If it
          # is slower than this, the ordering assertion below still holds -- the
          # test can pass vacuously, but it can never fail for timing reasons.
          sleep 0.2
          order << :holder_released
        end
        waiter.join
        expect(order).to eq(%i[holder_released waiter_ran])

        # The waiting acquire must release like the fail-fast one does.
        expect { |b| described_class.with_advisory_lock(db, &b) }.to yield_control
      ensure
        other_db.disconnect
      end
    end
  end

  describe 'batch size validation' do
    it 'rejects a batch size below 1, which would otherwise seed nothing while reporting success' do
      expect { described_class.seed_app_usage_events(db, logger, batch_size: 0) }.to raise_error(ArgumentError, /batch_size/)
      expect { described_class.seed_task_usage_events(db, logger, batch_size: -1) }.to raise_error(ArgumentError, /batch_size/)
      expect { described_class.seed_service_usage_events(db, logger, batch_size: '10') }.to raise_error(ArgumentError, /batch_size/)
    end
  end

  describe '.seed_app_usage_events' do
    it 'seeds one WAS_RUNNING row per started process across batches, skips stopped processes, and adds nothing when run again' do
      started1 = VCAP::CloudController::ProcessModelFactory.make(state: 'STARTED')
      started2 = VCAP::CloudController::ProcessModelFactory.make(state: 'STARTED')
      VCAP::CloudController::ProcessModelFactory.make(state: 'STOPPED')
      prune_usage_events!

      # batch_size: 1 forces the keyset loop to iterate once per process.
      described_class.seed_app_usage_events(db, logger, batch_size: 1)

      expect(app_was_running.select_map(:app_guid)).to contain_exactly(started1.guid, started2.guid)
      expect { described_class.seed_app_usage_events(db, logger, batch_size: 1) }.not_to change(app_was_running, :count)
    end

    it 'seeds a separate row per process when an app has multiple started processes' do
      app = create(:app_model)
      web = VCAP::CloudController::ProcessModelFactory.make(app: app, type: 'web', state: 'STARTED')
      worker = VCAP::CloudController::ProcessModelFactory.make(app: app, type: 'worker', state: 'STARTED')
      prune_usage_events!

      described_class.seed_app_usage_events(db, logger, batch_size: 1)

      scope = app_was_running.where(parent_app_guid: app.guid)
      expect(scope.select_map(:app_guid)).to contain_exactly(web.guid, worker.guid)
      expect(scope.select_map(:process_type)).to contain_exactly('web', 'worker')
    end

    it 'tolerates legacy NULLs in nullable process and app columns' do
      process = VCAP::CloudController::ProcessModelFactory.make(state: 'STARTED')
      prune_usage_events!
      # Bypass the model layer, which would backfill these defaults.
      db[:processes].where(guid: process.guid).update(memory: nil, instances: nil)

      described_class.seed_app_usage_events(db, logger)

      row = app_was_running.first(app_guid: process.guid)
      expect(row[:memory_in_mb_per_instance]).to eq(0)
      expect(row[:instance_count]).to eq(0)
    end

    it 'does not seed a baseline for a process that still has its real STARTED event' do
      process = VCAP::CloudController::ProcessModelFactory.make(state: 'STARTED')
      expect(db[:app_usage_events].where(state: 'STARTED', app_guid: process.guid).count).to eq(1)

      described_class.seed_app_usage_events(db, logger)

      # A consumer already tracks this process through its STARTED event.
      # Giving it a second start on record would make such a consumer bill it
      # twice.
      expect(app_was_running.where(app_guid: process.guid).count).to eq(0)
    end

    describe 'repairing stale baselines' do
      it 'appends a STOPPED event pairing baselines whose process is not running, without deleting any baseline' do
        running = VCAP::CloudController::ProcessModelFactory.make(state: 'STARTED')
        stopped = VCAP::CloudController::ProcessModelFactory.make(state: 'STOPPED')
        prune_usage_events!
        stale = create(:app_usage_event, state: 'WAS_RUNNING', app_guid: stopped.guid)
        create(:app_usage_event, state: 'WAS_RUNNING', app_guid: 'no-such-process')

        described_class.seed_app_usage_events(db, logger)

        # Baselines are never deleted: a consumer may already have read them.
        expect(app_was_running.select_map(:app_guid)).to contain_exactly(running.guid, stopped.guid, 'no-such-process')

        repair = db[:app_usage_events].where(state: 'STOPPED', app_guid: stopped.guid).first
        expect(repair).not_to be_nil
        expect(repair[:id]).to be > stale.id
        expect(repair[:guid]).to be_present
        expect(repair[:guid]).not_to eq(stale.guid)
        # previous_state is the baseline's state -- true (it was the last event
        # a consumer saw) and a marker: no normal STOPPED ever carries it.
        expect(repair[:previous_state]).to eq('WAS_RUNNING')
        expect(repair[:app_name]).to eq(stale.app_name)
        expect(repair[:space_guid]).to eq(stale.space_guid)
        expect(repair[:org_guid]).to eq(stale.org_guid)
        expect(repair[:instance_count]).to eq(stale.instance_count)
        expect(repair[:memory_in_mb_per_instance]).to eq(stale.memory_in_mb_per_instance)

        expect(db[:app_usage_events].where(state: 'STOPPED', app_guid: 'no-such-process').count).to eq(1)
        expect(db[:app_usage_events].where(state: 'STOPPED', app_guid: running.guid).count).to eq(0)
      end

      it 'leaves a baseline alone when a later real ending already pairs it, even across re-runs' do
        # Day 0: baseline seeded. Day 5: the app stops normally (a real
        # STOPPED, higher id). Day 10: a rake re-run must not touch either row
        # -- deleting the baseline would leave the STOPPED a consumer already
        # read pointing at nothing.
        stopped = VCAP::CloudController::ProcessModelFactory.make(state: 'STOPPED')
        prune_usage_events!
        create(:app_usage_event, state: 'WAS_RUNNING', app_guid: stopped.guid)
        create(:app_usage_event, state: 'STOPPED', app_guid: stopped.guid)

        expect { described_class.seed_app_usage_events(db, logger) }.not_to(change { db[:app_usage_events].count })
        expect(app_was_running.where(app_guid: stopped.guid).count).to eq(1)
      end

      it 'appends a later ending when the only stop event landed before the baseline (backfill/API race)' do
        stopped = VCAP::CloudController::ProcessModelFactory.make(state: 'STOPPED')
        prune_usage_events!
        create(:app_usage_event, state: 'STOPPED', app_guid: stopped.guid)
        baseline = create(:app_usage_event, state: 'WAS_RUNNING', app_guid: stopped.guid)

        described_class.seed_app_usage_events(db, logger)

        # A consumer reading forward saw the early stop first (a stop with no
        # start before it, which the docs say to ignore), then the baseline.
        # Only a LATER ending closes the baseline.
        expect(db[:app_usage_events].where(state: 'STOPPED', app_guid: stopped.guid).where { id > baseline.id }.count).to eq(1)
      end

      it 'does not add a second ending on a re-run: the one it added satisfies the next check' do
        stopped = VCAP::CloudController::ProcessModelFactory.make(state: 'STOPPED')
        prune_usage_events!
        create(:app_usage_event, state: 'WAS_RUNNING', app_guid: stopped.guid)

        described_class.seed_app_usage_events(db, logger)
        expect { described_class.seed_app_usage_events(db, logger) }.not_to(change { db[:app_usage_events].count })
      end

      it 'repairs across multiple batches when the stale set exceeds the batch size' do
        stopped = Array.new(3) { VCAP::CloudController::ProcessModelFactory.make(state: 'STOPPED') }
        prune_usage_events!
        stopped.each { |process| create(:app_usage_event, state: 'WAS_RUNNING', app_guid: process.guid) }

        # batch_size: 1 forces the repair loop to iterate once per baseline.
        described_class.seed_app_usage_events(db, logger, batch_size: 1)

        stopped.each do |process|
          expect(db[:app_usage_events].where(state: 'STOPPED', app_guid: process.guid).count).to eq(1)
        end
        # The repaired count accumulates across batches.
        expect(logger).to have_received(:info).with('added 3 STOPPED usage events to pair stale WAS_RUNNING baselines')
      end

      it 'stops repairing when a batch inserts nothing (all baselines invalidated in flight) rather than looping forever' do
        stopped = VCAP::CloudController::ProcessModelFactory.make(state: 'STOPPED')
        prune_usage_events!
        create(:app_usage_event, state: 'WAS_RUNNING', app_guid: stopped.guid)

        # Simulate every baseline in the batch being invalidated between
        # collecting the ids and inserting: the INSERT re-checks the staleness
        # test itself and matches no rows. The id-collecting SELECT still
        # returns the baseline, so without the zero-progress break the loop
        # would select the same ids forever.
        allow(db).to receive(:execute_dui).and_return(0)

        described_class.seed_app_usage_events(db, logger)

        expect(db[:app_usage_events].where(state: 'STOPPED').count).to eq(0)
      end
    end
  end

  describe '.seed_task_usage_events' do
    it 'seeds one TASK_WAS_RUNNING row per running task across batches, skips finished tasks, and adds nothing when run again' do
      running1 = create(:task_model, state: 'RUNNING', memory_in_mb: 256)
      running2 = create(:task_model, state: 'RUNNING')
      create(:task_model, state: 'SUCCEEDED')

      # batch_size: 1 forces the keyset loop to iterate once per task.
      described_class.seed_task_usage_events(db, logger, batch_size: 1)

      expect(task_was_running.select_map(:task_guid)).to contain_exactly(running1.guid, running2.guid)

      row = task_was_running.first(task_guid: running1.guid)
      expect(row[:previous_state]).to be_nil
      expect(row[:task_name]).to eq(running1.name)
      expect(row[:app_guid]).to eq('')
      expect(row[:app_name]).to eq('')
      expect(row[:parent_app_guid]).to eq(running1.app.guid)
      expect(row[:parent_app_name]).to eq(running1.app.name)
      expect(row[:instance_count]).to eq(1)
      expect(row[:memory_in_mb_per_instance]).to eq(256)
      expect(row[:previous_memory_in_mb_per_instance]).to eq(256)
      expect(row[:package_state]).to eq('STAGED')
      expect(row[:previous_package_state]).to eq('STAGED')
      expect(row[:space_guid]).to eq(running1.space.guid)
      expect(row[:space_name]).to eq(running1.space.name)
      expect(row[:org_guid]).to eq(running1.space.organization.guid)

      expect { described_class.seed_task_usage_events(db, logger, batch_size: 1) }.not_to change(task_was_running, :count)
    end

    it 'seeds CANCELING tasks, which are still running and billable until Diego reports them dead' do
      canceling = create(:task_model, state: 'CANCELING')

      described_class.seed_task_usage_events(db, logger)

      expect(task_was_running.select_map(:task_guid)).to contain_exactly(canceling.guid)
      # The repair must agree that CANCELING counts as running: writing a stop
      # here would make TaskModel think the task already stopped, and it would
      # skip the real stop later.
      expect(db[:app_usage_events].where(state: 'TASK_STOPPED', task_guid: canceling.guid).count).to eq(0)
    end

    it 'tolerates a legacy NULL task memory' do
      task = create(:task_model, state: 'RUNNING')
      # Bypass the model layer, which would backfill the default.
      db[:tasks].where(guid: task.guid).update(memory_in_mb: nil)

      described_class.seed_task_usage_events(db, logger)

      row = task_was_running.first(task_guid: task.guid)
      expect(row[:memory_in_mb_per_instance]).to eq(0)
    end

    it 'does not seed a baseline for a task that still has its real TASK_STARTED event' do
      running = create(:task_model, state: 'RUNNING')
      create(:app_usage_event, state: 'TASK_STARTED', task_guid: running.guid)

      described_class.seed_task_usage_events(db, logger)

      expect(task_was_running.count).to eq(0)
    end

    describe 'repairing stale baselines' do
      it 'appends a TASK_STOPPED event pairing baselines whose task is no longer running, without deleting any baseline' do
        running = create(:task_model, state: 'RUNNING')
        completed = create(:task_model, state: 'SUCCEEDED')
        stale = create(:app_usage_event, state: 'TASK_WAS_RUNNING', task_guid: completed.guid)
        create(:app_usage_event, state: 'TASK_WAS_RUNNING', task_guid: 'no-such-task')

        described_class.seed_task_usage_events(db, logger)

        # Baselines are never deleted: a consumer may already have read them.
        expect(task_was_running.select_map(:task_guid)).to contain_exactly(running.guid, completed.guid, 'no-such-task')

        repair = db[:app_usage_events].where(state: 'TASK_STOPPED', task_guid: completed.guid).first
        expect(repair).not_to be_nil
        expect(repair[:id]).to be > stale.id
        expect(repair[:previous_state]).to eq('TASK_WAS_RUNNING')
        expect(repair[:task_name]).to eq(stale.task_name)
        expect(repair[:app_guid]).to eq(stale.app_guid)
        expect(repair[:parent_app_guid]).to eq(stale.parent_app_guid)
        expect(repair[:memory_in_mb_per_instance]).to eq(stale.memory_in_mb_per_instance)

        expect(db[:app_usage_events].where(state: 'TASK_STOPPED', task_guid: 'no-such-task').count).to eq(1)
        expect(db[:app_usage_events].where(state: 'TASK_STOPPED', task_guid: running.guid).count).to eq(0)
      end

      it 'leaves a baseline alone when a later gated TASK_STOPPED already pairs it, even across re-runs' do
        completed = create(:task_model, state: 'SUCCEEDED')
        create(:app_usage_event, state: 'TASK_WAS_RUNNING', task_guid: completed.guid)
        create(:app_usage_event, state: 'TASK_STOPPED', task_guid: completed.guid)

        expect { described_class.seed_task_usage_events(db, logger) }.not_to(change { db[:app_usage_events].count })
        expect(task_was_running.where(task_guid: completed.guid).count).to eq(1)
      end
    end

    describe 'seed / stop / repair interleavings' do
      # An earlier version of the backfill DELETED baselines it thought were
      # stale, deciding from current resource state alone -- and deleted rows
      # that consumers (and TaskModel's stop-event check) had already used.
      # These scenarios are the regression net for that class of bug. Steps a
      # live foundation can interleave:
      #
      #   :backfill         -- a full backfill run (seed + repair), the way the
      #                        migration or the rake task runs it
      #   :task_canceled    -- an operator asks to cancel the task (-> CANCELING)
      #   :task_finishes    -- Diego reports the task dead; the model decides
      #                        whether to write the stop event
      #   :task_destroyed   -- the task row is destroyed while still running
      #                        (the app-deletion path)
      #   :task_row_wiped   -- the task row disappears with no hooks running
      #                        (a dataset-level delete)
      #   :phantom_baseline -- what a seed batch writes when its snapshot is
      #                        older than the task's death: a baseline for a
      #                        task that already stopped, silently
      #
      # The rule being checked: after any of these orderings, every beginning
      # event a consumer could have read for a now-stopped task has a later
      # ending event, and no baseline row has been deleted.
      [
        { name: 'gated stop after seed; a re-run must not unpair it',
          steps: %i[backfill task_finishes backfill], baselines: 1, stops: 1 },
        { name: 'task already CANCELING at seed time is baselined and eventually paired by its gated stop',
          steps: %i[task_canceled backfill task_finishes backfill], baselines: 1, stops: 1 },
        { name: 'task canceled after seeding keeps its baseline and gets no stop while it is still CANCELING',
          steps: %i[backfill task_canceled backfill], baselines: 1, stops: 0 },
        { name: 'phantom baseline for a task that already died silently; repair appends the missing stop',
          steps: %i[task_finishes phantom_baseline backfill], baselines: 1, stops: 1 },
        { name: 'task destroyed mid-run emits a gated stop against the baseline; a re-run is a no-op',
          steps: %i[backfill task_destroyed backfill], baselines: 1, stops: 1 },
        { name: 'task row wiped without hooks; repair appends the missing stop',
          steps: %i[backfill task_row_wiped backfill], baselines: 1, stops: 1 }
      ].each do |scenario|
        it "pairs every readable beginning: #{scenario[:name]}" do
          task = create(:task_model, state: 'RUNNING')

          scenario[:steps].each do |step|
            case step
            when :backfill then described_class.seed_task_usage_events(db, logger)
            when :task_canceled then task.update(state: 'CANCELING')
            when :task_finishes then task.update(state: 'FAILED')
            when :task_destroyed then task.destroy
            when :task_row_wiped then db[:tasks].where(guid: task.guid).delete
            when :phantom_baseline then create(:app_usage_event, state: 'TASK_WAS_RUNNING', task_guid: task.guid)
            end
          end

          baselines = task_was_running.where(task_guid: task.guid)
          stops = db[:app_usage_events].where(state: 'TASK_STOPPED', task_guid: task.guid)
          expect(baselines.count).to eq(scenario[:baselines])
          expect(stops.count).to eq(scenario[:stops])

          still_running = db[:tasks].where(guid: task.guid, state: %w[RUNNING CANCELING]).any?
          next if still_running

          db[:app_usage_events].where(state: %w[TASK_STARTED TASK_WAS_RUNNING], task_guid: task.guid).each do |beginning|
            expect(stops.where { id > beginning[:id] }.count).to be_positive,
                                                                 "beginning #{beginning[:state]} (id #{beginning[:id]}) has no later ending event"
          end
        end
      end
    end
  end

  describe '.seed_service_usage_events' do
    it 'seeds one WAS_RUNNING row per instance across multiple batches, with the right type, adding nothing when run again' do
      managed = create(:managed_service_instance)
      upsi = create(:user_provided_service_instance)
      prune_usage_events!

      # batch_size: 1 forces the keyset loop to iterate once per instance.
      described_class.seed_service_usage_events(db, logger, batch_size: 1)

      expect(was_running.select_map(:service_instance_guid)).to contain_exactly(managed.guid, upsi.guid)

      managed_row = was_running.first(service_instance_guid: managed.guid)
      expect(managed_row[:service_instance_type]).to eq('managed_service_instance')
      expect(managed_row[:service_plan_guid]).to eq(managed.service_plan.guid)
      expect(managed_row[:service_broker_name]).to eq(managed.service_plan.service.service_broker.name)

      upsi_row = was_running.first(service_instance_guid: upsi.guid)
      expect(upsi_row[:service_instance_type]).to eq('user_provided_service_instance')
      expect(upsi_row[:service_plan_guid]).to be_nil

      expect { described_class.seed_service_usage_events(db, logger, batch_size: 1) }.not_to change(was_running, :count)
    end

    it 'does not seed a baseline for an instance that still has its real CREATED or UPDATED event' do
      create(:managed_service_instance) # the factory itself writes the real CREATED event
      updated_only = create(:managed_service_instance)
      db[:service_usage_events].where(service_instance_guid: updated_only.guid).update(state: 'UPDATED')

      described_class.seed_service_usage_events(db, logger)

      expect(was_running.count).to eq(0)
    end

    describe 'repairing stale baselines' do
      it 'appends a DELETED event pairing baselines whose instance no longer exists, without deleting any baseline' do
        kept = create(:managed_service_instance)
        doomed = create(:managed_service_instance)
        prune_usage_events!

        described_class.seed_service_usage_events(db, logger)
        baseline = was_running.first(service_instance_guid: doomed.guid)
        db[:service_instances].where(guid: doomed.guid).delete

        described_class.seed_service_usage_events(db, logger)

        # Baselines are never deleted: a consumer may already have read them.
        expect(was_running.select_map(:service_instance_guid)).to contain_exactly(kept.guid, doomed.guid)

        repair = db[:service_usage_events].where(state: 'DELETED', service_instance_guid: doomed.guid).first
        expect(repair).not_to be_nil
        expect(repair[:id]).to be > baseline[:id]
        expect(repair[:guid]).to be_present
        expect(repair[:guid]).not_to eq(baseline[:guid])
        expect(repair[:service_instance_name]).to eq(baseline[:service_instance_name])
        expect(repair[:service_instance_type]).to eq(baseline[:service_instance_type])
        expect(repair[:service_plan_guid]).to eq(baseline[:service_plan_guid])
        expect(repair[:service_broker_guid]).to eq(baseline[:service_broker_guid])
        expect(repair[:space_guid]).to eq(baseline[:space_guid])
        expect(repair[:org_guid]).to eq(baseline[:org_guid])

        expect(db[:service_usage_events].where(state: 'DELETED', service_instance_guid: kept.guid).count).to eq(0)
      end

      it 'leaves a baseline alone when a later real DELETED already pairs it, even across re-runs' do
        create(:service_usage_event, state: 'WAS_RUNNING', service_instance_guid: 'gone-instance')
        create(:service_usage_event, state: 'DELETED', service_instance_guid: 'gone-instance')

        expect { described_class.seed_service_usage_events(db, logger) }.not_to(change { db[:service_usage_events].count })
        expect(was_running.where(service_instance_guid: 'gone-instance').count).to eq(1)
      end

      it 'does not add a second DELETED on a re-run: the one it added satisfies the next check' do
        create(:service_usage_event, state: 'WAS_RUNNING', service_instance_guid: 'gone-instance')

        described_class.seed_service_usage_events(db, logger)
        expect { described_class.seed_service_usage_events(db, logger) }.not_to(change { db[:service_usage_events].count })
      end
    end
  end
end
