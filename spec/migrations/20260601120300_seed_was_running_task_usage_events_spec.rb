require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to seed TASK_WAS_RUNNING events for currently-running tasks', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20260601120300_seed_was_running_task_usage_events.rb' }
  end

  let(:run_migration) do
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)
  end

  let(:revert_migration) do
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true)
  end

  # Builds an org/space/app scaffold and returns the app guid that tasks can reference.
  def seed_app(suffix)
    quota_id = db[:quota_definitions].insert(guid: "quota-#{suffix}", name: "quota-#{suffix}", non_basic_services_allowed: true,
                                             total_services: 10, memory_limit: 1024, total_routes: 10)
    org_id = db[:organizations].insert(guid: "org-#{suffix}", name: "org-#{suffix}", quota_definition_id: quota_id)
    db[:spaces].insert(guid: "space-#{suffix}", name: "space-#{suffix}", organization_id: org_id)
    db[:apps].insert(guid: "app-#{suffix}", name: "app-#{suffix}", space_guid: "space-#{suffix}")
    "app-#{suffix}"
  end

  def seed_task(suffix, state:, app_guid:, memory_in_mb: 256)
    db[:tasks].insert(guid: "task-#{suffix}", name: "task-#{suffix}", command: 'bundle exec rake', state: state,
                      app_guid: app_guid, droplet_guid: "droplet-#{suffix}", memory_in_mb: memory_in_mb)
  end

  def seed_task_event(suffix, state:, task_guid:)
    db[:app_usage_events].insert(guid: "event-#{suffix}", created_at: Time.now.utc, state: state,
                                 instance_count: 1, memory_in_mb_per_instance: 1, app_guid: '', app_name: '',
                                 space_guid: "space-#{suffix}", space_name: "space-#{suffix}", org_guid: "org-#{suffix}",
                                 task_guid: task_guid, task_name: "task-#{suffix}")
  end

  describe 'up migration' do
    it 'seeds TASK_WAS_RUNNING rows only for running tasks, skips finished ones, and preserves existing rows' do
      app_guid = seed_app('main')

      seed_task('running', state: 'RUNNING', app_guid: app_guid, memory_in_mb: 512)
      seed_task('succeeded', state: 'SUCCEEDED', app_guid: app_guid)
      seed_task('pending', state: 'PENDING', app_guid: app_guid)

      # A running task that already has a TASK_WAS_RUNNING row -> not duplicated
      seed_task('existing', state: 'RUNNING', app_guid: app_guid)
      seed_task_event('existing', state: 'TASK_WAS_RUNNING', task_guid: 'task-existing')

      # An unrelated pre-existing row that must be preserved (no truncate)
      preexisting_id = seed_task_event('unrelated', state: 'TASK_STARTED', task_guid: 'some-other-task')

      run_migration

      task_was_running = db[:app_usage_events].where(state: 'TASK_WAS_RUNNING')
      # One row for task-running, plus the pre-seeded task-existing row (not duplicated).
      expect(task_was_running.count).to eq(2)
      expect(task_was_running.where(task_guid: 'task-succeeded').count).to eq(0)
      expect(task_was_running.where(task_guid: 'task-pending').count).to eq(0)
      expect(task_was_running.where(task_guid: 'task-existing').count).to eq(1)
      expect(db[:app_usage_events].where(id: preexisting_id).count).to eq(1)

      row = task_was_running.where(task_guid: 'task-running').first
      expect(row[:guid]).to be_present
      expect(row[:previous_state]).to be_nil
      expect(row[:task_name]).to eq('task-running')
      expect(row[:app_guid]).to eq('')
      expect(row[:app_name]).to eq('')
      expect(row[:parent_app_guid]).to eq(app_guid)
      expect(row[:parent_app_name]).to eq('app-main')
      expect(row[:space_guid]).to eq('space-main')
      expect(row[:space_name]).to eq('space-main')
      expect(row[:org_guid]).to eq('org-main')
      expect(row[:instance_count]).to eq(1)
      expect(row[:previous_instance_count]).to eq(1)
      expect(row[:memory_in_mb_per_instance]).to eq(512)
      expect(row[:previous_memory_in_mb_per_instance]).to eq(512)
      expect(row[:package_state]).to eq('STAGED')
      expect(row[:previous_package_state]).to eq('STAGED')

      # Idempotency of the seeding itself (the NOT EXISTS guard) is covered in
      # spec/unit/lib/database/was_running_backfill_spec.rb, where seed_task_usage_events
      # runs twice; the migrator does not re-apply an already-recorded migration.
    end

    context 'when skip_was_running_backfill is set' do
      before do
        allow_any_instance_of(VCAP::CloudController::Config).to receive(:get).with(:skip_was_running_backfill).and_return(true)
      end

      it 'does not seed any TASK_WAS_RUNNING rows' do
        app_guid = seed_app('main')
        seed_task('skip', state: 'RUNNING', app_guid: app_guid)

        run_migration

        expect(db[:app_usage_events].where(state: 'TASK_WAS_RUNNING').count).to eq(0)
      end
    end
  end

  describe 'down migration' do
    it 'removes only the TASK_WAS_RUNNING rows' do
      app_guid = seed_app('main')
      seed_task('down', state: 'RUNNING', app_guid: app_guid)
      unrelated_id = seed_task_event('unrelated', state: 'TASK_STARTED', task_guid: 'some-other-task')

      run_migration
      expect(db[:app_usage_events].where(state: 'TASK_WAS_RUNNING').count).to eq(1)

      revert_migration
      expect(db[:app_usage_events].where(state: 'TASK_WAS_RUNNING').count).to eq(0)
      expect(db[:app_usage_events].where(id: unrelated_id).count).to eq(1)
    end
  end
end
