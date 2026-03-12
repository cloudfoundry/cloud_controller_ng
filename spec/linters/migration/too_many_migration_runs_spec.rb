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

  it 'counts migrations via subject, let, let!, and helper methods' do
    source = <<~RUBY
      RSpec.describe('m') do
        subject(:migrate_subj) { #{migration_call(1)} }
        let(:migrate_let) { #{migration_call(2)} }
        let!(:migrate_let_bang) { #{migration_call(3)} }
        def migrate_method; #{migration_call(4)}; end

        it('t1') { migrate_subj }
        it('t2') { migrate_let }
        it('t3') { migrate_let_bang }
        it('t4') { migrate_method }
        it('t5') { migrate_subj }
      end
    RUBY
    result = inspect_source(source)
    expect(result.size).to eq(1)
    expect(result.first.message).to include('(5)')
  end

  it 'does not double-count definitions - only invocations' do
    source = <<~RUBY
      RSpec.describe('m') do
        subject(:migrate) { #{migration_call(1)} }
        it('t1') { migrate }
        it('t2') { migrate }
        it('t3') { migrate }
        it('t4') { migrate }
      end
    RUBY
    result = inspect_source(source)
    expect(result).to be_empty
  end

  it 'counts migrations in before/after blocks' do
    source = <<~RUBY
      RSpec.describe('m') do
        before { #{migration_call(1)}; #{migration_call(2)} }
        after { #{migration_call(3)} }
        it('t1') { #{migration_call(4)} }
        it('t2') { #{migration_call(5)} }
      end
    RUBY
    result = inspect_source(source)
    expect(result.size).to eq(1)
    expect(result.first.message).to include('(5)')
  end

  it 'does not count non-migration let invocations' do
    source = <<~RUBY
      RSpec.describe('m') do
        let(:value) { 'not a migration' }
        #{(1..4).map { |n| "it('t#{n}') { value; #{migration_call(n)} }" }.join("\n")}
      end
    RUBY
    result = inspect_source(source)
    expect(result).to be_empty
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
