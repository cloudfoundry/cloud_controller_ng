require 'spec_helper'
require 'rubocop'
require 'rubocop/rspec/cop_helper'
require 'rubocop/config'
require 'linters/migration/require_primary_key'

RSpec.describe RuboCop::Cop::Migration::RequirePrimaryKey do
  include CopHelper

  subject(:cop) { RuboCop::Cop::Migration::RequirePrimaryKey.new(RuboCop::Config.new({})) }

  let(:primary_key_message) do
    'Please include a call to primary_key when creating a table. This is to ensure compatibility with clustered databases.'
  end

  it 'registers an offense if create_table is called without adding a primary key' do
    result = inspect_source(<<~RUBY)
      create_table :foobar do
        String :carly
      end
    RUBY

    expect(result.size).to eq(1)
    expect(result.map(&:message)).to eq([primary_key_message])
  end

  it 'does not register an offense if create_table is called with a call to primary_key' do
    result = inspect_source(<<~RUBY)
      create_table :foobar do
        String :carly
        primary_key :super-unique
      end
    RUBY

    expect(result.size).to eq(0)
  end

  it 'does not register an offense if create_table is called with a call VCAP::Migration.common' do
    result = inspect_source(<<~RUBY)
      create_table :foobar do
        VCAP::Migration.common(self)
        String :carly
      end
    RUBY

    expect(result.size).to eq(0)
  end
end
