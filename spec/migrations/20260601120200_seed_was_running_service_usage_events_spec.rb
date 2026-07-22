require 'spec_helper'
require 'migrations/helpers/migration_shared_context'
require 'database/was_running_backfill'

RSpec.describe 'migration to seed WAS_RUNNING events for existing service instances', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20260601120200_seed_was_running_service_usage_events.rb' }
  end

  let(:run_migration) do
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)
  end

  let(:revert_migration) do
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true)
  end

  # Builds an org/space scaffold and returns the space id that instances can reference.
  def seed_space(suffix)
    quota_id = db[:quota_definitions].insert(guid: "quota-#{suffix}", name: "quota-#{suffix}", non_basic_services_allowed: true,
                                             total_services: 10, memory_limit: 1024, total_routes: 10)
    org_id = db[:organizations].insert(guid: "org-#{suffix}", name: "org-#{suffix}", quota_definition_id: quota_id)
    db[:spaces].insert(guid: "space-#{suffix}", name: "space-#{suffix}", organization_id: org_id)
  end

  # Builds a broker -> service -> plan chain and returns the plan id.
  def seed_plan(suffix)
    broker_id = db[:service_brokers].insert(guid: "broker-#{suffix}", name: "broker-#{suffix}", broker_url: 'http://example.com', auth_password: 'pw')
    service_id = db[:services].insert(guid: "service-#{suffix}", label: "service-#{suffix}", description: 'desc', bindable: true, service_broker_id: broker_id)
    db[:service_plans].insert(guid: "plan-#{suffix}", name: "plan-#{suffix}", description: 'desc', free: true, service_id: service_id, unique_id: "plan-unique-#{suffix}")
  end

  def seed_service_event(suffix, state:, service_instance_guid:)
    db[:service_usage_events].insert(guid: "event-#{suffix}", created_at: Time.now.utc, state: state,
                                     org_guid: 'org-main', space_guid: 'space-main', space_name: 'space-main',
                                     service_instance_guid: service_instance_guid, service_instance_name: "instance-#{suffix}",
                                     service_instance_type: 'managed_service_instance')
  end

  describe 'up migration' do
    it 'seeds one WAS_RUNNING row per instance with the correct type and preserves existing rows' do
      # Seeding must happen under the advisory lock, WAITING for a concurrent
      # backfill (e.g. an operator's rake run) rather than failing the deploy.
      # at_least: the spec harness replays the remaining seed migrations in an
      # after-hook, so the lock is taken more than once per example.
      expect(VCAP::WasRunningBackfill).to receive(:with_advisory_lock).with(anything, wait: true).at_least(:once).and_call_original

      space_id = seed_space('main')
      plan_id = seed_plan('main')

      # A managed instance -> managed_service_instance type with full broker chain.
      db[:service_instances].insert(guid: 'managed-guid', name: 'my-instance', space_id: space_id, is_gateway_service: true, service_plan_id: plan_id)
      # A user-provided instance -> user_provided_service_instance type with NULL plan/service/broker.
      db[:service_instances].insert(guid: 'upsi-guid', name: 'upsi', space_id: space_id, is_gateway_service: false)

      # A managed instance that already has a WAS_RUNNING row -> not duplicated.
      db[:service_instances].insert(guid: 'existing-guid', name: 'existing', space_id: space_id, is_gateway_service: true, service_plan_id: plan_id)
      seed_service_event('existing', state: 'WAS_RUNNING', service_instance_guid: 'existing-guid')

      # An instance that still has its real CREATED event -> no baseline. A
      # consumer already tracks it; a second start on record would make it get
      # billed twice.
      db[:service_instances].insert(guid: 'created-guid', name: 'created', space_id: space_id, is_gateway_service: true, service_plan_id: plan_id)
      seed_service_event('created', state: 'CREATED', service_instance_guid: 'created-guid')

      # An unrelated pre-existing row that must be preserved (no truncate).
      preexisting_id = seed_service_event('unrelated', state: 'CREATED', service_instance_guid: 'some-other-instance')

      run_migration

      was_running = db[:service_usage_events].where(state: 'WAS_RUNNING')
      # One row each for managed-guid and upsi-guid, plus the pre-seeded existing-guid row (not duplicated).
      expect(was_running.count).to eq(3)
      expect(was_running.where(service_instance_guid: 'existing-guid').count).to eq(1)
      expect(was_running.where(service_instance_guid: 'created-guid').count).to eq(0)
      expect(db[:service_usage_events].where(id: preexisting_id).count).to eq(1)

      managed_row = was_running.where(service_instance_guid: 'managed-guid').first
      expect(managed_row[:guid]).to be_present
      expect(managed_row[:service_instance_name]).to eq('my-instance')
      expect(managed_row[:service_instance_type]).to eq('managed_service_instance')
      expect(managed_row[:service_plan_guid]).to eq('plan-main')
      expect(managed_row[:service_plan_name]).to eq('plan-main')
      expect(managed_row[:service_guid]).to eq('service-main')
      expect(managed_row[:service_label]).to eq('service-main')
      expect(managed_row[:service_broker_name]).to eq('broker-main')
      expect(managed_row[:service_broker_guid]).to eq('broker-main')
      expect(managed_row[:space_guid]).to eq('space-main')
      expect(managed_row[:space_name]).to eq('space-main')
      expect(managed_row[:org_guid]).to eq('org-main')

      upsi_row = was_running.where(service_instance_guid: 'upsi-guid').first
      expect(upsi_row[:service_instance_type]).to eq('user_provided_service_instance')
      expect(upsi_row[:service_plan_guid]).to be_nil
      expect(upsi_row[:service_plan_name]).to be_nil
      expect(upsi_row[:service_guid]).to be_nil
      expect(upsi_row[:service_label]).to be_nil
      expect(upsi_row[:service_broker_name]).to be_nil
      expect(upsi_row[:service_broker_guid]).to be_nil

      # Idempotency of the seeding itself (the NOT EXISTS guard) is covered in
      # spec/unit/lib/database/was_running_backfill_spec.rb, where seed_service_usage_events
      # runs twice; the migrator does not re-apply an already-recorded migration.
    end

    context 'when skip_was_running_backfill is set' do
      before do
        allow_any_instance_of(VCAP::CloudController::Config).to receive(:get).with(:skip_was_running_backfill).and_return(true)
      end

      it 'does not seed any WAS_RUNNING rows' do
        space_id = seed_space('main')
        plan_id = seed_plan('main')
        db[:service_instances].insert(guid: 'managed-guid', name: 'my-instance', space_id: space_id, is_gateway_service: true, service_plan_id: plan_id)

        run_migration

        expect(db[:service_usage_events].where(state: 'WAS_RUNNING').count).to eq(0)
      end
    end
  end

  describe 'down migration' do
    it 'keeps the WAS_RUNNING rows: consumers may already have read them' do
      space_id = seed_space('main')
      plan_id = seed_plan('main')
      db[:service_instances].insert(guid: 'managed-guid', name: 'my-instance', space_id: space_id, is_gateway_service: true, service_plan_id: plan_id)
      unrelated_id = seed_service_event('unrelated', state: 'CREATED', service_instance_guid: 'some-other-instance')

      run_migration
      expect(db[:service_usage_events].where(state: 'WAS_RUNNING').count).to eq(1)

      revert_migration
      expect(db[:service_usage_events].where(state: 'WAS_RUNNING').count).to eq(1)
      expect(db[:service_usage_events].where(id: unrelated_id).count).to eq(1)
    end
  end
end
