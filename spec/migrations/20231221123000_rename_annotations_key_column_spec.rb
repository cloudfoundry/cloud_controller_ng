require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to streamline changes to annotation_key_prefix', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20231221123000_rename_annotations_key_column.rb' }
  end

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

  describe 'annotation tables' do
    it 'has renamed the column key to key_name' do
      annotation_tables.each do |table|
        expect(db[table.to_sym].columns).to include(:key)
        expect(db[table.to_sym].columns).not_to include(:key_name)
      end
      expect { Sequel::Migrator.run(db, migration_to_test, allow_missing_migration_files: true) }.not_to raise_error
      annotation_tables.each do |table|
        expect(db[table.to_sym].columns).not_to include(:key)
        expect(db[table.to_sym].columns).to include(:key_name)
      end
    end
  end
end
