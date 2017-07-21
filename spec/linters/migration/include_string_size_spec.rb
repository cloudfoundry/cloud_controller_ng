require 'spec_helper'
require 'rubocop'
require 'rubocop/rspec/cop_helper'
require 'rubocop/config'
require 'linters/migration/include_string_size'

RSpec.describe RuboCop::Cop::Migration::IncludeStringSize do
  include CopHelper

  RSpec.shared_examples 'a cop that validates inclusion of string size' do |method_name|
    it 'registers an offense if string column is added without a specified size' do
      inspect_source(cop, [
        'create_table :jobs do',
        "#{method_name} :my_table, :my_column, String",
        'end'
      ])

      expect(cop.offenses.size).to eq(1)
      expect(cop.messages).to eq(['Please explicitly set your string size.'])
    end

    it 'does not register an offense if string has a size' do
      inspect_source(cop, [
        'create_table :jobs do',
        "#{method_name} :my_table, :my_column, String, size: 1",
        'end'
      ])

      expect(cop.offenses.size).to eq(0)
      expect(cop.messages).to be_empty
    end
  end

  subject(:cop) { described_class.new(RuboCop::Config.new({})) }

  context 'when the method is add_column' do
    it_behaves_like 'a cop that validates inclusion of string size', :add_column
  end

  context 'when the method is set_column_type' do
    it_behaves_like 'a cop that validates inclusion of string size', :set_column_type
  end

  context 'when the table is being created' do
    it 'registers an offense if string column is added without a specified size' do
      inspect_source(cop, [
        'create_table :jobs do',
        'String :my_column',
        'end'
      ])

      expect(cop.offenses.size).to eq(1)
      expect(cop.messages).to eq(['Please explicitly set your string size.'])
    end

    it 'does not register an offense if string has a size' do
      inspect_source(cop, [
        'create_table :jobs do',
        'String :my_column, size: 1',
        'end'
      ])

      expect(cop.offenses.size).to eq(0)
      expect(cop.messages).to be_empty
    end
  end
end
