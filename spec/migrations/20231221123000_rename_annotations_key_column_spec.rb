require 'spec_helper'

RSpec.describe 'migration to streamline changes to annotation_key_prefix', isolation: :truncation do
  let(:filename) { '20231221123000_rename_annotations_key_column.rb' }
  let(:tmp_down_migrations_dir) { Dir.mktmpdir }
  let(:tmp_up_migrations_dir) { Dir.mktmpdir }
  let(:db) { Sequel::Model.db }
  let(:tables) do
    %w[
      app
      build
      buildpack
      deployment
      domain
      droplet
      isolation_segment
      organization
      package
      process
      revision
      route_binding
      route
      service_binding
      service_broker
      service_broker_update_request
      service_instance
      service_key
      service_offering
      service_plan
      space
      stack
      task
      user
    ].freeze
  end

  let(:annotation_tables) { tables.map { |tbn| "#{tbn}_annotations" }.freeze }

  before do
    Sequel.extension :migration
    # Find all migrations
    migration_files = Dir.glob("#{DBMigrator::SEQUEL_MIGRATIONS}/*.rb")
    # Calculate the index of our migration file we`d  like to test
    migration_index = migration_files.find_index { |file| file.end_with?(filename) }
    # Make a file list of the migration file we like to test plus all migrations after the one we want to test
    migration_files_after_test = migration_files[migration_index...]
    # Copy them to a temp directory
    FileUtils.cp(migration_files_after_test, tmp_down_migrations_dir)
    FileUtils.cp(File.join(DBMigrator::SEQUEL_MIGRATIONS, filename), tmp_up_migrations_dir)
    # Revert the given migration and everything newer so we are at the database version exactly before our migration we want to test.
    Sequel::Migrator.run(db, tmp_down_migrations_dir, target: 0, allow_missing_migration_files: true)
  end

  after do
    FileUtils.rm_rf(tmp_up_migrations_dir)
    FileUtils.rm_rf(tmp_down_migrations_dir)
  end

  describe 'annotation tables' do
    it 'has renamed the column key to key_name' do
      annotation_tables.each do |table|
        expect(db[table.to_sym].columns).to include(:key)
        expect(db[table.to_sym].columns).not_to include(:key_name)
      end
      expect { Sequel::Migrator.run(db, tmp_up_migrations_dir, allow_missing_migration_files: true) }.not_to raise_error
      annotation_tables.each do |table|
        expect(db[table.to_sym].columns).not_to include(:key)
        expect(db[table.to_sym].columns).to include(:key_name)
      end
    end
  end
end
