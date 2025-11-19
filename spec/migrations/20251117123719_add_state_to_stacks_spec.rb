require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add state column to stacks table', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20251117123719_add_state_to_stacks.rb' }
  end

  describe 'stacks table' do
    subject(:run_migration) { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }

    describe 'up' do
      it 'adds a column `state`' do
        expect(db[:stacks].columns).not_to include(:state)
        run_migration
        expect(db[:stacks].columns).to include(:state)
      end

      it 'sets the default value of existing stacks to ACTIVE' do
        db[:stacks].insert(guid: SecureRandom.uuid, name: 'existing-stack', description: 'An existing stack')
        run_migration
        expect(db[:stacks].first(name: 'existing-stack')[:state]).to eq('ACTIVE')
      end

      it 'sets the default value of new stacks to ACTIVE' do
        run_migration
        db[:stacks].insert(guid: SecureRandom.uuid, name: 'new-stack', description: 'A new stack')
        expect(db[:stacks].first(name: 'new-stack')[:state]).to eq('ACTIVE')
      end

      it 'forbids null values' do
        run_migration
        expect do
          db[:stacks].insert(guid: SecureRandom.uuid, name: 'null-state-stack', description: 'A stack with null state', state: nil)
        end.to raise_error(Sequel::NotNullConstraintViolation)
      end

      it 'allows valid state values' do
        run_migration
        %w[ACTIVE DEPRECATED RESTRICTED DISABLED].each do |state|
          expect do
            db[:stacks].insert(guid:SecureRandom.uuid, name: "stack-#{state.downcase}", description: "A #{state} stack", state: state)
          end.not_to raise_error
          expect(db[:stacks].first(name: "stack-#{state.downcase}")[:state]).to eq(state)
        end
      end

      context 'when the column already exists' do
        before do
          db.alter_table :stacks do
            add_column :state, String, null: false, default: 'ACTIVE', size: 255 unless @db.schema(:stacks).map(&:first).include?(:state)
          end
        end

        it 'does not fail' do
          expect(db[:stacks].columns).to include(:state)
          expect { run_migration }.not_to raise_error
          expect(db[:stacks].columns).to include(:state)
        end
      end
    end

    describe 'down' do
      subject(:run_rollback) { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }

      before do
        run_migration
      end

      it 'removes the `state` column' do
        expect(db[:stacks].columns).to include(:state)
        run_rollback
        expect(db[:stacks].columns).not_to include(:state)
      end

      context 'when the column does not exist' do
        before do
          db.alter_table :stacks do
            drop_column :state if @db.schema(:stacks).map(&:first).include?(:state)
          end
        end

        it 'does not fail' do
          expect(db[:stacks].columns).not_to include(:state)
          expect { run_rollback }.not_to raise_error
          expect(db[:stacks].columns).not_to include(:state)
        end
      end
    end
  end
end
