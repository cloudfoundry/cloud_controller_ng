require 'spec_helper'
require 'rubocop'
require 'rubocop/rspec/cop_helper'
require 'rubocop/config'
require 'linters/migration/require_primary_key'

RSpec.describe RuboCop::Cop::Migration::RequirePrimaryKey do
  include CopHelper

  let(:primary_key_message) do
    'Please include a call to primary_key when creating a table. This is to ensure compatibility with clustered databases.'
  end

  subject(:cop) { RuboCop::Cop::Migration::RequirePrimaryKey.new(RuboCop::Config.new({})) }

  it 'registers an offense if create_table is called without adding a primary key', focus: true do
    inspect_source(['create_table :foobar do', 'String :carly', 'end'])

    expect(cop.offenses.size).to eq(1)
    expect(cop.messages).to eq([primary_key_message])
  end

  it 'does not register an offense if create_table is called with a call to primary_key' do
    inspect_source(['create_table :foobar do', 'String :carly', 'primary_key :super-unique', 'end'])

    expect(cop.offenses.size).to eq(0)
  end

  it 'does not register an offense if create_table is called with a call VCAP::Migration.common' do
    inspect_source(['create_table :foobar do', 'VCAP::Migration.common(self)', 'String :carly', 'end'])

    expect(cop.offenses.size).to eq(0)
  end
end
