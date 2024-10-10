require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe "migration to add foreign key on column 'droplet_guid' in table 'apps'", isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20240904132000_add_foreign_key_apps_droplet_guid.rb' }
  end

  describe 'apps table' do
    after do
      db[:apps].delete
    end

    context 'before adding the foreign key' do
      it 'allows inserts with a droplet_guid that does not exist' do
        expect { db[:apps].insert(guid: 'app_guid', droplet_guid: 'not_exists') }.not_to raise_error
      end
    end

    context 'after adding the foreign key' do
      it 'prevents inserts with a droplet_guid that does not exist' do
        Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

        expect { db[:apps].insert(guid: 'app_guid', droplet_guid: 'not_exists') }.to raise_error(Sequel::ForeignKeyConstraintViolation)
      end

      it 'removed references to not existing droplets' do
        db[:droplets].insert(guid: 'droplet_guid', state: 'some_state')
        db[:apps].insert(guid: 'app_guid', droplet_guid: 'droplet_guid')
        db[:apps].insert(guid: 'another_app_guid', droplet_guid: 'not_exists')

        Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

        expect(db[:apps].where(guid: 'app_guid').get(:droplet_guid)).to eq('droplet_guid')
        expect(db[:apps].where(guid: 'another_app_guid').get(:droplet_guid)).to be_nil
      end
    end
  end
end
