require 'spec_helper'
require 'rubocop'
require 'rubocop/rspec/cop_helper'
require 'rubocop/config'
require 'linters/migration/use_migration_helpers'

RSpec.describe RuboCop::Cop::Migration::UseMigrationHelpers do
  include CopHelper

  subject(:cop) { described_class.new(RuboCop::Config.new({})) }

  let(:message) { described_class::MSG }

  it 'registers an offense for Sequel::Migrator.run inside an example when the context is present' do
    result = inspect_source(<<~RUBY)
      RSpec.describe 'migration' do
        include_context 'migration' do
          let(:migration_filename) { 'x.rb' }
        end

        it 'runs' do
          expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index) }.not_to raise_error
        end
      end
    RUBY

    expect(result.size).to eq(1)
    expect(result.map(&:message)).to eq([message])
  end

  it 'registers an offense for an unqualified Migrator.run when the context is present' do
    result = inspect_source(<<~RUBY)
      RSpec.describe 'migration' do
        include_context 'migration' do
          let(:migration_filename) { 'x.rb' }
        end

        it 'runs' do
          expect { Migrator.run(db, migrations_path, target: current_migration_index) }.not_to raise_error
        end
      end
    RUBY

    expect(result.size).to eq(1)
  end

  it 'registers one offense per direct call' do
    result = inspect_source(<<~RUBY)
      RSpec.describe 'migration' do
        include_context 'migration' do
          let(:migration_filename) { 'x.rb' }
        end

        it 'runs' do
          Sequel::Migrator.run(db, migrations_path, target: current_migration_index)
          Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1)
        end
      end
    RUBY

    expect(result.size).to eq(2)
  end

  it 'does not register an offense for a call inside a before hook' do
    result = inspect_source(<<~RUBY)
      RSpec.describe 'migration' do
        include_context 'migration' do
          let(:migration_filename) { 'x.rb' }
        end

        before do
          Sequel::Migrator.run(db, migrations_path, target: current_migration_index)
        end
      end
    RUBY

    expect(result.size).to eq(0)
  end

  it 'does not register an offense for a call inside an after hook' do
    result = inspect_source(<<~RUBY)
      RSpec.describe 'migration' do
        include_context 'migration' do
          let(:migration_filename) { 'x.rb' }
        end

        after do
          Sequel::Migrator.run(db, migrations_path, target: current_migration_index)
        end
      end
    RUBY

    expect(result.size).to eq(0)
  end

  it 'does not register an offense for a call inside an around hook' do
    result = inspect_source(<<~RUBY)
      RSpec.describe 'migration' do
        include_context 'migration' do
          let(:migration_filename) { 'x.rb' }
        end

        around do |example|
          Sequel::Migrator.run(db, migrations_path, target: current_migration_index)
          example.run
        end
      end
    RUBY

    expect(result.size).to eq(0)
  end

  it 'does not register an offense when the migration shared context is absent' do
    result = inspect_source(<<~RUBY)
      RSpec.describe 'migration' do
        it 'runs' do
          expect { Sequel::Migrator.run(db, migrations_path, target: 1) }.not_to raise_error
        end
      end
    RUBY

    expect(result.size).to eq(0)
  end

  it 'does not register an offense when the helpers are used' do
    result = inspect_source(<<~RUBY)
      RSpec.describe 'migration' do
        include_context 'migration' do
          let(:migration_filename) { 'x.rb' }
        end

        it 'runs' do
          expect { run_migration }.not_to raise_error
          test_up_migration_idempotency
        end
      end
    RUBY

    expect(result.size).to eq(0)
  end
end
