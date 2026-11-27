require 'migration_spec_helper'

RSpec.describe 'backfill status_value for deployments', isolation: :truncation, type: :migration do
  let(:db) { Sequel::Model.db }
  let(:tmp_migrations_dir) { Dir.mktmpdir }

  before do
    FileUtils.cp(
      File.join(DBMigrator::SEQUEL_MIGRATIONS, '20190712210940_backfill_status_for_deployments.rb'),
      tmp_migrations_dir
    )
  end

  it 'backfills status_value based on deployment state' do
    now = Time.now.utc
    app_guid = SecureRandom.uuid
    db[:apps].insert(guid: app_guid, name: 'app', created_at: now, updated_at: now)

    db[:deployments].insert(guid: 'with-state-deployed', app_guid: app_guid, state: 'DEPLOYED', original_web_process_instance_count: 1, created_at: now, updated_at: now)
    db[:deployments].insert(guid: 'with-state-canceled', app_guid: app_guid, state: 'CANCELED', original_web_process_instance_count: 1, created_at: now, updated_at: now)
    db[:deployments].insert(guid: 'with-state-failed', app_guid: app_guid, state: 'FAILED', original_web_process_instance_count: 1, created_at: now, updated_at: now)
    db[:deployments].insert(guid: 'with-state-deploying', app_guid: app_guid, state: 'DEPLOYING', original_web_process_instance_count: 1, created_at: now, updated_at: now)
    db[:deployments].insert(guid: 'with-state-canceling', app_guid: app_guid, state: 'CANCELING', original_web_process_instance_count: 1, created_at: now, updated_at: now)
    db[:deployments].insert(guid: 'with-state-failing', app_guid: app_guid, state: 'FAILING', original_web_process_instance_count: 1, created_at: now, updated_at: now)
    db[:deployments].insert(guid: 'with-existing-status', app_guid: app_guid, state: 'DEPLOYED', status_value: 'foo', status_reason: 'bar', original_web_process_instance_count: 1,
                            created_at: now, updated_at: now)
    db[:deployments].insert(guid: 'failing-with-reason', app_guid: app_guid, state: 'FAILING', status_value: 'foo', status_reason: 'bar', original_web_process_instance_count: 1,
                            created_at: now, updated_at: now)

    Sequel::Migrator.run(db, tmp_migrations_dir, table: :my_fake_table)

    deployment = db[:deployments].where(guid: 'with-state-deployed').first
    expect(deployment[:state]).to eq('DEPLOYED')
    expect(deployment[:status_value]).to eq('FINALIZED')
    expect(deployment[:status_reason]).to be_nil

    deployment = db[:deployments].where(guid: 'with-state-canceled').first
    expect(deployment[:state]).to eq('CANCELED')
    expect(deployment[:status_value]).to eq('FINALIZED')
    expect(deployment[:status_reason]).to be_nil

    deployment = db[:deployments].where(guid: 'with-state-failed').first
    expect(deployment[:state]).to eq('DEPLOYED')
    expect(deployment[:status_value]).to eq('FINALIZED')
    expect(deployment[:status_reason]).to be_nil

    deployment = db[:deployments].where(guid: 'with-state-deploying').first
    expect(deployment[:state]).to eq('DEPLOYING')
    expect(deployment[:status_value]).to eq('DEPLOYING')
    expect(deployment[:status_reason]).to be_nil

    deployment = db[:deployments].where(guid: 'with-state-canceling').first
    expect(deployment[:state]).to eq('CANCELING')
    expect(deployment[:status_value]).to eq('DEPLOYING')
    expect(deployment[:status_reason]).to be_nil

    deployment = db[:deployments].where(guid: 'with-state-failing').first
    expect(deployment[:state]).to eq('DEPLOYING')
    expect(deployment[:status_value]).to eq('DEPLOYING')
    expect(deployment[:status_reason]).to be_nil

    deployment = db[:deployments].where(guid: 'with-existing-status').first
    expect(deployment[:state]).to eq('DEPLOYED')
    expect(deployment[:status_value]).to eq('foo')
    expect(deployment[:status_reason]).to eq('bar')

    deployment = db[:deployments].where(guid: 'failing-with-reason').first
    expect(deployment[:state]).to eq('DEPLOYING')
    expect(deployment[:status_value]).to eq('DEPLOYING')
    expect(deployment[:status_reason]).to eq('bar')
  end
end
