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

  describe 'WAS_RUNNING' do
    # The backfill is raw SQL (no CC code), so it can't reference the repository
    # constants directly. This guard catches any drift between the literal the
    # backfill writes and the state value the repositories/cleanup recognise.
    it 'matches the state value used by the usage event repositories' do
      expect(described_class::WAS_RUNNING).to eq(VCAP::CloudController::Repositories::AppUsageEventRepository::WAS_RUNNING_EVENT_STATE)
      expect(described_class::WAS_RUNNING).to eq(VCAP::CloudController::Repositories::ServiceUsageEventRepository::WAS_RUNNING_EVENT_STATE)
      expect(described_class::TASK_WAS_RUNNING).to eq(VCAP::CloudController::Repositories::AppUsageEventRepository::TASK_WAS_RUNNING_EVENT_STATE)
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

  describe '.seed_app_usage_events' do
    it 'seeds one WAS_RUNNING row per started process across batches, idempotently, skipping stopped processes' do
      started1 = VCAP::CloudController::ProcessModelFactory.make(state: 'STARTED')
      started2 = VCAP::CloudController::ProcessModelFactory.make(state: 'STARTED')
      VCAP::CloudController::ProcessModelFactory.make(state: 'STOPPED')

      # batch_size: 1 forces the keyset loop to iterate once per process.
      described_class.seed_app_usage_events(db, logger, batch_size: 1)

      expect(app_was_running.select_map(:app_guid)).to contain_exactly(started1.guid, started2.guid)
      expect { described_class.seed_app_usage_events(db, logger, batch_size: 1) }.not_to change(app_was_running, :count)
    end

    it 'seeds a separate row per process when an app has multiple started processes' do
      app = create(:app_model)
      web = VCAP::CloudController::ProcessModelFactory.make(app: app, type: 'web', state: 'STARTED')
      worker = VCAP::CloudController::ProcessModelFactory.make(app: app, type: 'worker', state: 'STARTED')

      described_class.seed_app_usage_events(db, logger, batch_size: 1)

      scope = app_was_running.where(parent_app_guid: app.guid)
      expect(scope.select_map(:app_guid)).to contain_exactly(web.guid, worker.guid)
      expect(scope.select_map(:process_type)).to contain_exactly('web', 'worker')
    end

    it 'tolerates legacy NULLs in nullable process and app columns' do
      process = VCAP::CloudController::ProcessModelFactory.make(state: 'STARTED')
      # Bypass the model layer, which would backfill these defaults.
      db[:processes].where(guid: process.guid).update(memory: nil, instances: nil)

      described_class.seed_app_usage_events(db, logger)

      row = app_was_running.first(app_guid: process.guid)
      expect(row[:memory_in_mb_per_instance]).to eq(0)
      expect(row[:instance_count]).to eq(0)
    end

    it 'sweeps WAS_RUNNING rows whose process is not running, e.g. apps stopped concurrently with the backfill' do
      running = VCAP::CloudController::ProcessModelFactory.make(state: 'STARTED')
      stopped = VCAP::CloudController::ProcessModelFactory.make(state: 'STOPPED')
      create(:app_usage_event, state: 'WAS_RUNNING', app_guid: stopped.guid)
      create(:app_usage_event, state: 'WAS_RUNNING', app_guid: 'no-such-process')

      described_class.seed_app_usage_events(db, logger)

      expect(app_was_running.select_map(:app_guid)).to contain_exactly(running.guid)
    end
  end

  describe '.delete_app_usage_events' do
    it 'batch-deletes only WAS_RUNNING rows' do
      VCAP::CloudController::ProcessModelFactory.make(state: 'STARTED')
      described_class.seed_app_usage_events(db, logger, batch_size: 1)
      started = create(:app_usage_event, state: 'STARTED')

      described_class.delete_app_usage_events(db, batch_size: 1)

      expect(app_was_running.count).to eq(0)
      expect(db[:app_usage_events].where(guid: started.guid).count).to eq(1)
    end
  end

  describe '.seed_task_usage_events' do
    it 'seeds one TASK_WAS_RUNNING row per running task across batches, idempotently, skipping completed tasks' do
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

    it 'tolerates a legacy NULL task memory' do
      task = create(:task_model, state: 'RUNNING')
      # Bypass the model layer, which would backfill the default.
      db[:tasks].where(guid: task.guid).update(memory_in_mb: nil)

      described_class.seed_task_usage_events(db, logger)

      row = task_was_running.first(task_guid: task.guid)
      expect(row[:memory_in_mb_per_instance]).to eq(0)
    end

    it 'sweeps TASK_WAS_RUNNING rows whose task is no longer running, e.g. tasks completed concurrently with the backfill' do
      running = create(:task_model, state: 'RUNNING')
      completed = create(:task_model, state: 'SUCCEEDED')
      create(:app_usage_event, state: 'TASK_WAS_RUNNING', task_guid: completed.guid)
      create(:app_usage_event, state: 'TASK_WAS_RUNNING', task_guid: 'no-such-task')

      described_class.seed_task_usage_events(db, logger)

      expect(task_was_running.select_map(:task_guid)).to contain_exactly(running.guid)
    end
  end

  describe '.delete_task_usage_events' do
    it 'batch-deletes only TASK_WAS_RUNNING rows' do
      task = create(:task_model, state: 'RUNNING')
      described_class.seed_task_usage_events(db, logger, batch_size: 1)
      task_started = create(:app_usage_event, state: 'TASK_STARTED', task_guid: task.guid)
      app_baseline = create(:app_usage_event, state: 'WAS_RUNNING', app_guid: 'some-process')

      described_class.delete_task_usage_events(db, batch_size: 1)

      expect(task_was_running.count).to eq(0)
      expect(db[:app_usage_events].where(guid: task_started.guid).count).to eq(1)
      expect(db[:app_usage_events].where(guid: app_baseline.guid).count).to eq(1)
    end
  end

  describe '.seed_service_usage_events' do
    it 'seeds one WAS_RUNNING row per instance across multiple batches, with the right type, idempotently' do
      managed = create(:managed_service_instance)
      upsi = create(:user_provided_service_instance)

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

    it 'sweeps WAS_RUNNING rows whose service instance no longer exists, e.g. instances deleted concurrently with the backfill' do
      instance = create(:managed_service_instance)
      create(:service_usage_event, state: 'WAS_RUNNING', service_instance_guid: 'no-such-instance')

      described_class.seed_service_usage_events(db, logger)

      expect(was_running.select_map(:service_instance_guid)).to contain_exactly(instance.guid)
    end
  end

  describe '.delete_service_usage_events' do
    it 'batch-deletes only WAS_RUNNING rows' do
      instance = create(:managed_service_instance)
      described_class.seed_service_usage_events(db, logger, batch_size: 1)
      created = create(:service_usage_event, state: 'CREATED', service_instance_guid: instance.guid)

      described_class.delete_service_usage_events(db, batch_size: 1)

      expect(was_running.count).to eq(0)
      expect(db[:service_usage_events].where(guid: created.guid).count).to eq(1)
    end
  end
end
