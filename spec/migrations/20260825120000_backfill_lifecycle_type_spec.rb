require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to backfill lifecycle_type on apps, droplets, and builds', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20260825120000_backfill_lifecycle_type.rb' }
  end

  before do
    db[:apps].insert(guid: 'buildpack-app-guid')
    db[:apps].insert(guid: 'cnb-app-guid')
    db[:apps].insert(guid: 'docker-app-guid')
    db[:apps].insert(guid: 'already-set-guid')
    db[:apps].insert(guid: 'both-app-guid')

    db[:buildpack_lifecycle_data].insert(guid: 'bld-app-guid', app_guid: 'buildpack-app-guid')
    db[:cnb_lifecycle_data].insert(guid: 'cnb-app-guid-data', app_guid: 'cnb-app-guid')
    db[:buildpack_lifecycle_data].insert(guid: 'bld-both-guid', app_guid: 'both-app-guid')
    db[:cnb_lifecycle_data].insert(guid: 'cnb-both-guid', app_guid: 'both-app-guid')

    db[:apps].where(guid: 'already-set-guid').update(lifecycle_type: 'docker')

    db[:droplets].insert(guid: 'buildpack-droplet-guid', state: 'STAGED')
    db[:droplets].insert(guid: 'cnb-droplet-guid', state: 'STAGED')
    db[:droplets].insert(guid: 'docker-droplet-guid', state: 'STAGED')

    db[:buildpack_lifecycle_data].insert(guid: 'bld-droplet-guid', droplet_guid: 'buildpack-droplet-guid')
    db[:cnb_lifecycle_data].insert(guid: 'cnb-droplet-guid-data', droplet_guid: 'cnb-droplet-guid')

    db[:builds].insert(guid: 'buildpack-build-guid')
    db[:builds].insert(guid: 'cnb-build-guid')
    db[:builds].insert(guid: 'docker-build-guid')

    db[:buildpack_lifecycle_data].insert(guid: 'bld-build-guid', build_guid: 'buildpack-build-guid')
    db[:cnb_lifecycle_data].insert(guid: 'cnb-build-guid-data', build_guid: 'cnb-build-guid')
  end

  it 'backfills lifecycle_type for apps, droplets, and builds, does not overwrite existing values, and prefers buildpack over cnb' do
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

    expect(db[:apps].first(guid: 'buildpack-app-guid')[:lifecycle_type]).to eq('buildpack')
    expect(db[:apps].first(guid: 'cnb-app-guid')[:lifecycle_type]).to eq('cnb')
    expect(db[:apps].first(guid: 'docker-app-guid')[:lifecycle_type]).to eq('docker')
    expect(db[:apps].first(guid: 'already-set-guid')[:lifecycle_type]).to eq('docker')
    expect(db[:apps].first(guid: 'both-app-guid')[:lifecycle_type]).to eq('buildpack')

    expect(db[:droplets].first(guid: 'buildpack-droplet-guid')[:lifecycle_type]).to eq('buildpack')
    expect(db[:droplets].first(guid: 'cnb-droplet-guid')[:lifecycle_type]).to eq('cnb')
    expect(db[:droplets].first(guid: 'docker-droplet-guid')[:lifecycle_type]).to eq('docker')

    expect(db[:builds].first(guid: 'buildpack-build-guid')[:lifecycle_type]).to eq('buildpack')
    expect(db[:builds].first(guid: 'cnb-build-guid')[:lifecycle_type]).to eq('cnb')
    expect(db[:builds].first(guid: 'docker-build-guid')[:lifecycle_type]).to eq('docker')

    expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
  end
end
