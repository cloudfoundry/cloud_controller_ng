require 'rubocop'
require 'rubocop/rspec/cop_helper'
require 'rubocop/config'
require 'linters/migration/too_many_migration_runs'

RSpec.describe RuboCop::Cop::Migration::TooManyMigrationRuns do
  include CopHelper

  subject(:cop) { described_class.new(RuboCop::Config.new({})) }

  def migration_call(target)
    "Sequel::Migrator.run(db, path, target: #{target})"
  end

  def it_blocks(count)
    (1..count).map { |n| "it('test #{n}') { #{migration_call(n)} }" }.join("\n")
  end

  it 'does not register an offense for 4 or fewer direct migration calls' do
    result = inspect_source("RSpec.describe('m') do\n#{it_blocks(4)}\nend")
    expect(result).to be_empty
  end

  it 'registers an offense for more than 4 direct migration calls' do
    result = inspect_source("RSpec.describe('m') do\n#{it_blocks(5)}\nend")
    expect(result.size).to eq(1)
    expect(result.first.message).to include('(5)')
  end

  it 'does not register an offense for 4 or fewer shared-context helper calls' do
    %w[run_migration revert_migration test_up_migration_idempotency test_down_migration_idempotency].each do |helper|
      source = <<~RUBY
        RSpec.describe('m') do
          include_context 'migration'
          #{(1..4).map { |n| "it('t#{n}') { #{helper} }" }.join("\n")}
        end
      RUBY

      expect(inspect_source(source)).to be_empty, "Expected no offense for #{helper}"
    end
  end

  it 'registers an offense for more than 4 shared-context helper calls' do
    %w[run_migration revert_migration test_up_migration_idempotency test_down_migration_idempotency].each do |helper|
      source = <<~RUBY
        RSpec.describe('m') do
          include_context 'migration'
          #{(1..5).map { |n| "it('t#{n}') { #{helper} }" }.join("\n")}
        end
      RUBY

      result = inspect_source(source)
      expect(result.size).to eq(1), "Expected offense for #{helper}"
      expect(result.first.message).to include('(5)')
    end
  end

  it 'counts a mix of direct calls and all four shared-context helpers' do
    source = <<~RUBY
      RSpec.describe('m') do
        include_context 'migration'
        it('test') do
          #{migration_call(1)}
          run_migration
          revert_migration
          test_up_migration_idempotency
          test_down_migration_idempotency
        end
      end
    RUBY

    result = inspect_source(source)
    expect(result.size).to eq(1)
    expect(result.first.message).to include('(5)')
  end

  it 'counts explicit self helper calls only in files including the migration shared context' do
    source = <<~RUBY
      RSpec.describe('m') do
        include_context 'migration'
        #{(1..5).map { |n| "it('t#{n}') { self.run_migration }" }.join("\n")}
      end
    RUBY

    result = inspect_source(source)
    expect(result.size).to eq(1)
    expect(result.first.message).to include('(5)')

    expect(inspect_source(source.sub("include_context 'migration'", "include_context 'other'"))).to be_empty
    expect(inspect_source(source).size).to eq(1)
  end

  it 'does not count calls to similarly named methods on other objects' do
    source = <<~RUBY
      RSpec.describe('m') do
        it('test') do
          runner.run_migration
          runner.revert_migration
          runner.test_up_migration_idempotency
          runner.test_down_migration_idempotency
          runner.run_migration
        end
      end
    RUBY

    expect(inspect_source(source)).to be_empty
  end

  it 'counts multiple migrations in a single it block' do
    source = <<~RUBY
      RSpec.describe('m') do
        it('test') do
          #{(1..5).map { |n| migration_call(n) }.join("\n")}
        end
      end
    RUBY
    result = inspect_source(source)
    expect(result.size).to eq(1)
    expect(result.first.message).to include('(5)')
  end

  it 'counts migrations via subject, let, let!, and local wrapper methods' do
    [migration_call(1), 'run_migration'].each do |call|
      migration_context = "include_context 'migration'" if call == 'run_migration'
      source = <<~RUBY
        RSpec.describe('m') do
          #{migration_context}
          subject(:migrate_subj) { #{call} }
          let(:migrate_let) { #{call} }
          let!(:migrate_let_bang) { #{call} }
          def migrate_method; #{call}; end

          it('t1') { migrate_subj }
          it('t2') { migrate_let }
          it('t3') { migrate_let_bang }
          it('t4') { migrate_method }
          it('t5') { migrate_subj }
        end
      RUBY
      result = inspect_source(source)
      expect(result.size).to eq(1), "Expected offense for wrappers containing #{call}"
      expect(result.first.message).to include('(5)')
    end
  end

  it 'does not double-count definitions - only invocations' do
    [migration_call(1), 'run_migration'].each do |call|
      source = <<~RUBY
        RSpec.describe('m') do
          include_context 'migration'
          subject(:migrate) { #{call} }
          it('t1') { migrate }
          it('t2') { migrate }
          it('t3') { migrate }
          it('t4') { migrate }
        end
      RUBY
      result = inspect_source(source)
      expect(result).to be_empty, "Expected no offense for a subject containing #{call}"
    end
  end

  it 'counts migrations in before/after/around blocks' do
    [migration_call(2), 'run_migration'].each do |call|
      source = <<~RUBY
        RSpec.describe('m') do
          include_context 'migration'
          before { #{migration_call(1)}; #{call} }
          after { #{call} }
          around { |example| #{call}; example.run }
          it('test') { #{call} }
        end
      RUBY
      result = inspect_source(source)
      expect(result.size).to eq(1), "Expected offense for hooks containing #{call}"
      expect(result.first.message).to include('(5)')
    end
  end

  it 'does not count non-migration let invocations' do
    %w[value run_migration revert_migration test_up_migration_idempotency test_down_migration_idempotency].each do |name|
      source = <<~RUBY
        RSpec.describe('m') do
          let(:#{name}) { 'not a migration' }
          #{(1..4).map { |n| "it('t#{n}') { #{name}; #{migration_call(n)} }" }.join("\n")}
        end
      RUBY

      expect(inspect_source(source)).to be_empty, "Expected no offense for unrelated #{name}"
    end
  end

  it 'handles empty files and files without migrations' do
    expect(inspect_source('')).to be_empty
    expect(inspect_source("RSpec.describe('x') { it('y') { expect(1).to eq(1) } }")).to be_empty
  end

  it 'detects ::Sequel::Migrator.run and bare Migrator.run' do
    %w[::Sequel::Migrator Migrator].each do |const|
      source = "RSpec.describe('m') do\n#{(1..5).map { |n| "it('t#{n}') { #{const}.run(db, path, target: #{n}) }" }.join("\n")}\nend"
      result = inspect_source(source)
      expect(result.size).to eq(1), "Expected offense for #{const}.run"
    end
  end
end
