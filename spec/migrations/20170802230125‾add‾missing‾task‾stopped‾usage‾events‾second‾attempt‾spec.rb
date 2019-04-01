require 'spec_helper'

RSpec.describe 'Backfill missing task stopped usage events', isolation: :truncation do
  let(:tmp_migrations_dir) { Dir.mktmpdir }
  let(:start_event_created_at) { Time.new(2017, 1, 1) }

  before do
    FileUtils.cp(
      File.join(DBMigrator::SEQUEL_MIGRATIONS, '20170802230125_add_missing_task_stopped_usage_events_second_attempt.rb'),
      tmp_migrations_dir,
    )

    VCAP::CloudController::AppUsageEvent.make(state: 'TASK_STARTED', task_guid: 'my-task-guid1', created_at: start_event_created_at)
  end

  it 'backfills missing task stop usage events' do
    VCAP::CloudController::AppUsageEvent.make(state: 'TASK_STOPPED', task_guid: 'my-task-guid3')
    expect(VCAP::CloudController::AppUsageEvent.where(state: 'TASK_STOPPED', task_guid: 'my-task-guid1').count).to eq(0)

    Sequel::Migrator.run(VCAP::CloudController::AppModel.db, tmp_migrations_dir, table: :my_fake_table)

    expect(VCAP::CloudController::AppUsageEvent.where(state: 'TASK_STOPPED', task_guid: 'my-task-guid1').count).to eq(1)

    backfilled_stop_event = VCAP::CloudController::AppUsageEvent.find(state: 'TASK_STOPPED', task_guid: 'my-task-guid1')
    expect(backfilled_stop_event.created_at).to eq(start_event_created_at + 1.second)
  end

  context 'when there is already a stop event' do
    before do
      VCAP::CloudController::AppUsageEvent.make(state: 'TASK_STARTED', task_guid: 'my-task-guid2')
      VCAP::CloudController::AppUsageEvent.make(state: 'TASK_STOPPED', task_guid: 'my-task-guid2')
    end

    it 'does not backfill a missing task stop usage event' do
      expect(VCAP::CloudController::AppUsageEvent.where(state: 'TASK_STOPPED', task_guid: 'my-task-guid2').count).to eq(1)
      Sequel::Migrator.run(VCAP::CloudController::AppModel.db, tmp_migrations_dir, table: :my_fake_table)

      expect(VCAP::CloudController::AppUsageEvent.where(state: 'TASK_STOPPED', task_guid: 'my-task-guid2').count).to eq(1)
    end
  end

  context 'when there is only a stop event (because start event rotated out)' do
    before do
      VCAP::CloudController::AppUsageEvent.make(state: 'TASK_STOPPED', task_guid: 'my-task-guid3')
    end

    it 'does not backfill a missing task stop usage event' do
      expect(VCAP::CloudController::AppUsageEvent.where(state: 'TASK_STOPPED', task_guid: 'my-task-guid3').count).to eq(1)
      Sequel::Migrator.run(VCAP::CloudController::AppModel.db, tmp_migrations_dir, table: :my_fake_table)

      expect(VCAP::CloudController::AppUsageEvent.where(state: 'TASK_STOPPED', task_guid: 'my-task-guid3').count).to eq(1)
    end
  end

  context 'when a task exists' do
    let(:task) { VCAP::CloudController::TaskModel.make }

    before do
      VCAP::CloudController::AppUsageEvent.make(state: 'TASK_STARTED', task_guid: task.guid)
    end

    it 'does not backfill the task stop usage event' do
      Sequel::Migrator.run(VCAP::CloudController::AppModel.db, tmp_migrations_dir, table: :my_fake_table)

      expect(VCAP::CloudController::AppUsageEvent.where(state: 'TASK_STOPPED', task_guid: task.guid).count).to eq(0)
    end
  end
end
