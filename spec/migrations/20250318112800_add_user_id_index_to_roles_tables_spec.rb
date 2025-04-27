require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.shared_examples 'adding an index for table' do |table|
  describe "#{table} table" do
    let(:table_sym) { table.to_sym }
    let(:index_sym) { :"#{table}_user_id_index" }

    before do
      skip unless db.database_type == :postgres
    end

    describe 'up migration' do
      context 'index does not exist' do
        it 'adds the index' do
          expect(db.indexes(table_sym)).not_to include(index_sym)
          expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
          expect(db.indexes(table_sym)).to include(index_sym)
        end
      end

      context 'index already exists' do
        before do
          db.add_index table_sym, :user_id, name: index_sym
        end

        it 'does not fail' do
          expect(db.indexes(table_sym)).to include(index_sym)
          expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
          expect(db.indexes(table_sym)).to include(index_sym)
        end
      end
    end

    describe 'down migration' do
      before do
        Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)
      end

      context 'index exists' do
        it 'removes the index' do
          expect(db.indexes(table_sym)).to include(index_sym)
          expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
          expect(db.indexes(table_sym)).not_to include(index_sym)
        end
      end

      context 'index does not exist' do
        before do
          db.drop_index table_sym, :user_id, name: index_sym
        end

        it 'does not fail' do
          expect(db.indexes(table_sym)).not_to include(index_sym)
          expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
          expect(db.indexes(table_sym)).not_to include(index_sym)
        end
      end
    end
  end
end

RSpec.describe 'migration to add an index for user_id on all roles tables', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20250318112800_add_user_id_index_to_roles_tables.rb' }
  end

  include_examples 'adding an index for table', 'organizations_auditors'
  include_examples 'adding an index for table', 'organizations_billing_managers'
  include_examples 'adding an index for table', 'organizations_managers'
  include_examples 'adding an index for table', 'organizations_users'
  include_examples 'adding an index for table', 'spaces_auditors'
  include_examples 'adding an index for table', 'spaces_developers'
  include_examples 'adding an index for table', 'spaces_managers'
  include_examples 'adding an index for table', 'spaces_supporters'
end
