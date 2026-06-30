require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to seed WAS_RUNNING events for currently-running app processes', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20260601120100_seed_was_running_app_usage_events.rb' }
  end

  let(:run_migration) do
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)
  end

  let(:revert_migration) do
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true)
  end

  # Builds an org/space scaffold and returns the space guid that apps can reference.
  def seed_space(suffix)
    quota_id = db[:quota_definitions].insert(guid: "quota-#{suffix}", name: "quota-#{suffix}", non_basic_services_allowed: true,
                                             total_services: 10, memory_limit: 1024, total_routes: 10)
    org_id = db[:organizations].insert(guid: "org-#{suffix}", name: "org-#{suffix}", quota_definition_id: quota_id)
    db[:spaces].insert(guid: "space-#{suffix}", name: "space-#{suffix}", organization_id: org_id)
    "space-#{suffix}"
  end

  def seed_app_event(suffix, state:, app_guid:)
    db[:app_usage_events].insert(guid: "event-#{suffix}", created_at: Time.now.utc, state: state,
                                 instance_count: 1, memory_in_mb_per_instance: 1, app_guid: app_guid, app_name: "app-#{suffix}",
                                 space_guid: "space-#{suffix}", space_name: "space-#{suffix}", org_guid: "org-#{suffix}")
  end

  describe 'up migration' do
    it 'seeds WAS_RUNNING rows only for started processes, skips stopped ones, and preserves existing rows' do
      space_guid = seed_space('main')

      # A running process with no droplet -> package_state PENDING
      db[:apps].insert(guid: 'app-pending', name: 'pending-app', space_guid: space_guid)
      db[:processes].insert(guid: 'proc-pending', app_guid: 'app-pending', state: 'STARTED', instances: 3, memory: 512, type: 'web')

      # A running process whose app points at a STAGED droplet -> package_state STAGED.
      # Insert order avoids the apps.droplet_guid <-> droplets <-> packages.app_guid FK cycle.
      db[:apps].insert(guid: 'app-staged', name: 'staged-app', space_guid: space_guid)
      db[:packages].insert(guid: 'pkg-staged', app_guid: 'app-staged', state: 'READY')
      db[:droplets].insert(guid: 'drop-staged', package_guid: 'pkg-staged', state: 'STAGED')
      db[:apps].where(guid: 'app-staged').update(droplet_guid: 'drop-staged')
      db[:processes].insert(guid: 'proc-staged', app_guid: 'app-staged', state: 'STARTED', instances: 1, memory: 256, type: 'web')

      # A running process whose latest droplet FAILED -> package_state FAILED
      db[:apps].insert(guid: 'app-faildrop', name: 'faildrop-app', space_guid: space_guid)
      db[:packages].insert(guid: 'pkg-faildrop', app_guid: 'app-faildrop', state: 'READY')
      db[:droplets].insert(guid: 'drop-faildrop', package_guid: 'pkg-faildrop', state: 'FAILED')
      db[:apps].where(guid: 'app-faildrop').update(droplet_guid: 'drop-faildrop')
      db[:processes].insert(guid: 'proc-faildrop', app_guid: 'app-faildrop', state: 'STARTED', instances: 1, memory: 128, type: 'web')

      # A running process whose latest package FAILED (and has no droplet) -> package_state FAILED
      db[:apps].insert(guid: 'app-failpkg', name: 'failpkg-app', space_guid: space_guid)
      db[:packages].insert(guid: 'pkg-failpkg', app_guid: 'app-failpkg', state: 'FAILED')
      db[:processes].insert(guid: 'proc-failpkg', app_guid: 'app-failpkg', state: 'STARTED', instances: 1, memory: 128, type: 'web')

      # A stopped process -> no WAS_RUNNING row
      db[:apps].insert(guid: 'app-stopped', name: 'stopped-app', space_guid: space_guid)
      db[:processes].insert(guid: 'proc-stopped', app_guid: 'app-stopped', state: 'STOPPED', instances: 1, memory: 128, type: 'web')

      # A running process that already has a WAS_RUNNING row -> not duplicated
      db[:apps].insert(guid: 'app-existing', name: 'existing-app', space_guid: space_guid)
      db[:processes].insert(guid: 'proc-existing', app_guid: 'app-existing', state: 'STARTED', instances: 1, memory: 128, type: 'web')
      seed_app_event('existing', state: 'WAS_RUNNING', app_guid: 'proc-existing')

      # An unrelated pre-existing row that must be preserved (no truncate)
      preexisting_id = seed_app_event('unrelated', state: 'STARTED', app_guid: 'some-other-guid')

      run_migration

      was_running = db[:app_usage_events].where(state: 'WAS_RUNNING')
      # One row each for proc-pending, proc-staged, proc-faildrop and proc-failpkg, plus the
      # pre-seeded proc-existing row (not duplicated).
      expect(was_running.count).to eq(5)
      expect(was_running.where(app_guid: 'proc-stopped').count).to eq(0)
      expect(was_running.where(app_guid: 'proc-existing').count).to eq(1)
      expect(db[:app_usage_events].where(id: preexisting_id).count).to eq(1)

      pending_row = was_running.where(app_guid: 'proc-pending').first
      expect(pending_row[:guid]).to be_present
      expect(pending_row[:previous_state]).to be_nil
      expect(pending_row[:app_name]).to eq('pending-app')
      expect(pending_row[:parent_app_guid]).to eq('app-pending')
      expect(pending_row[:parent_app_name]).to eq('pending-app')
      expect(pending_row[:process_type]).to eq('web')
      expect(pending_row[:space_guid]).to eq(space_guid)
      expect(pending_row[:space_name]).to eq('space-main')
      expect(pending_row[:org_guid]).to eq('org-main')
      expect(pending_row[:instance_count]).to eq(3)
      expect(pending_row[:previous_instance_count]).to eq(3)
      expect(pending_row[:memory_in_mb_per_instance]).to eq(512)
      expect(pending_row[:previous_memory_in_mb_per_instance]).to eq(512)
      expect(pending_row[:package_state]).to eq('PENDING')
      expect(pending_row[:previous_package_state]).to eq('UNKNOWN')

      expect(was_running.where(app_guid: 'proc-staged').first[:package_state]).to eq('STAGED')
      expect(was_running.where(app_guid: 'proc-faildrop').first[:package_state]).to eq('FAILED')
      expect(was_running.where(app_guid: 'proc-failpkg').first[:package_state]).to eq('FAILED')

      # Idempotency of the seeding itself (the NOT EXISTS guard) is covered in
      # spec/unit/lib/database/was_running_backfill_spec.rb, where seed_app_usage_events
      # runs twice; the migrator does not re-apply an already-recorded migration.
    end

    context 'when skip_was_running_backfill is set' do
      before do
        allow_any_instance_of(VCAP::CloudController::Config).to receive(:get).with(:skip_was_running_backfill).and_return(true)
      end

      it 'does not seed any WAS_RUNNING rows' do
        space_guid = seed_space('main')
        db[:apps].insert(guid: 'app-skip', name: 'skip-app', space_guid: space_guid)
        db[:processes].insert(guid: 'proc-skip', app_guid: 'app-skip', state: 'STARTED', instances: 1, memory: 128, type: 'web')

        run_migration

        expect(db[:app_usage_events].where(state: 'WAS_RUNNING').count).to eq(0)
      end
    end
  end

  describe 'down migration' do
    it 'removes only the WAS_RUNNING rows' do
      space_guid = seed_space('main')
      db[:apps].insert(guid: 'app-down', name: 'down-app', space_guid: space_guid)
      db[:processes].insert(guid: 'proc-down', app_guid: 'app-down', state: 'STARTED', instances: 1, memory: 128, type: 'web')
      unrelated_id = seed_app_event('unrelated', state: 'STARTED', app_guid: 'some-other-guid')

      run_migration
      expect(db[:app_usage_events].where(state: 'WAS_RUNNING').count).to eq(1)

      revert_migration
      expect(db[:app_usage_events].where(state: 'WAS_RUNNING').count).to eq(0)
      expect(db[:app_usage_events].where(id: unrelated_id).count).to eq(1)
    end
  end
end
