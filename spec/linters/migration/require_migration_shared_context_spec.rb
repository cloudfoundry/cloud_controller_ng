require 'spec_helper'
require 'rubocop'
require 'rubocop/rspec/cop_helper'
require 'rubocop/config'
require 'linters/migration/require_migration_shared_context'

RSpec.describe RuboCop::Cop::Migration::RequireMigrationSharedContext do
  include CopHelper

  subject(:cop) { described_class.new(RuboCop::Config.new({})) }

  let(:message) { described_class::MSG }

  it 'registers an offense when the migration shared context is missing' do
    result = inspect_source(<<~RUBY)
      RSpec.describe 'adds a column' do
        it 'works' do
          expect(true).to be(true)
        end
      end
    RUBY

    expect(result.size).to eq(1)
    expect(result.map(&:message)).to eq([message])
  end

  it 'does not register an offense when the context is included via a block' do
    result = inspect_source(<<~RUBY)
      RSpec.describe 'adds a column' do
        include_context 'migration' do
          let(:migration_filename) { 'x.rb' }
        end
      end
    RUBY

    expect(result.size).to eq(0)
  end

  it 'does not register an offense for the bare include_context form' do
    result = inspect_source(<<~RUBY)
      RSpec.describe 'adds a column' do
        include_context 'migration'
      end
    RUBY

    expect(result.size).to eq(0)
  end

  it 'registers an offense when only a different shared context is included' do
    result = inspect_source(<<~RUBY)
      RSpec.describe 'adds a column' do
        include_context 'bigint migration step1' do
          let(:migration_filename) { 'x.rb' }
        end
      end
    RUBY

    expect(result.size).to eq(1)
  end
end
