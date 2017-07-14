require 'spec_helper'
require 'rubocop'
require 'rubocop/rspec/cop_helper'
require 'rubocop/config'
require 'linters/migration/add_constraint_name'

RSpec.describe RuboCop::Cop::Migration::AddConstraintName do
  include CopHelper

  RSpec.shared_examples 'a cop that validates explicit names are added to the index' do |method_name|
    it 'registers an offense if index is called without a name' do
      inspect_source(cop, [
        'create_table :jobs do',
        "#{method_name} :foo",
        'end'
      ])

      expect(cop.offenses.size).to eq(1)
      expect(cop.messages).to eq(['Please explicitly name your index or constraint.'])
    end

    it 'does not register an offense if index is called with a name' do
      inspect_source(cop, [
        'create_table :jobs do',
        "#{method_name} :foo, name: :bar",
        'end'
      ])

      expect(cop.offenses.size).to eq(0)
      expect(cop.messages).to be_empty
    end
  end

  RSpec.shared_examples 'a cop that validates explicit names are used when adding a column with an index' do |method_name|
    context 'and the column is adding an index' do
      it 'registers an offense if index is called without a name' do
        inspect_source(cop, [
          'create_table :jobs do',
          "#{method_name} :foo, :index",
          'end'
        ])

        expect(cop.offenses.size).to eq(1)
        expect(cop.messages).to eq(['Please explicitly name your index or constraint.'])
      end

      it 'does not register an offense if index is called with a name' do
        inspect_source(cop, [
          'create_table :jobs do',
          "#{method_name} :foo, index: {name: 'foo'}",
          'end'
        ])

        expect(cop.offenses.size).to eq(0)
        expect(cop.messages).to be_empty
      end
    end

    context 'and the column is adding a unique constraint' do
      it 'registers an offense if unique is called without a unique_constraint_name' do
        inspect_source(cop, [
          'create_table :jobs do',
          "#{method_name} :foo, unique: true",
          'end'
        ])

        expect(cop.offenses.size).to eq(1)
        expect(cop.messages).to eq(['Please explicitly name your index or constraint.'])
      end

      it 'does not register an offense if unique is called with a unique_constraint_name' do
        inspect_source(cop, [
          'create_table :jobs do',
          "#{method_name} :foo, unique: true, unique_constraint_name: 'something_real_unique'",
          'end'
        ])

        expect(cop.offenses.size).to eq(0)
        expect(cop.messages).to be_empty
      end
    end

    context 'and the column is adding a primary_key constraint' do
      it 'registers an offense if unique is called without a primary_key_constraint_name' do
        inspect_source(cop, [
          'create_table :jobs do',
          "#{method_name} :foo, primary_key: true",
          'end'
        ])

        expect(cop.offenses.size).to eq(1)
        expect(cop.messages).to eq(['Please explicitly name your index or constraint.'])
      end

      it 'does not register an offense if primary_key is called with a primary_key_constraint_name' do
        inspect_source(cop, [
          'create_table :jobs do',
          "#{method_name} :foo, primary_key: true, primary_key_constraint_name: 'something_real_unique'",
          'end'
        ])

        expect(cop.offenses.size).to eq(0)
        expect(cop.messages).to be_empty
      end
    end

    context 'and the column is not adding any index or constraint' do
      it 'does not register an offense' do
        inspect_source(cop, [
          'create_table :jobs do',
          "#{method_name} :foo",
          'end'
        ])

        expect(cop.offenses.size).to eq(0)
        expect(cop.messages).to be_empty
      end
    end
  end

  subject(:cop) { described_class.new(RuboCop::Config.new({})) }

  context 'when the method is add_unique_constraint' do
    it_behaves_like 'a cop that validates explicit names are added to the index', :add_unique_constraint
  end

  context 'when the method is add_constraint' do
    it_behaves_like 'a cop that validates explicit names are added to the index', :add_constraint
  end

  context 'when the method is add_foreign_key' do
    it_behaves_like 'a cop that validates explicit names are added to the index', :add_foreign_key
  end

  context 'when the method is add_index' do
    it_behaves_like 'a cop that validates explicit names are added to the index', :add_index
  end

  context 'when the method is add_primary_key' do
    it_behaves_like 'a cop that validates explicit names are added to the index', :add_primary_key
  end

  context 'when the method is add_full_text_index' do
    it_behaves_like 'a cop that validates explicit names are added to the index', :add_full_text_index
  end

  context 'when the method is add_spatial_index' do
    it_behaves_like 'a cop that validates explicit names are added to the index', :add_spatial_index
  end

  context 'when the method is unique_constraint' do
    it_behaves_like 'a cop that validates explicit names are added to the index', :unique_constraint
  end

  context 'when the method is constraint' do
    it_behaves_like 'a cop that validates explicit names are added to the index', :constraint
  end

  context 'when the method is foreign_key' do
    it_behaves_like 'a cop that validates explicit names are added to the index', :foreign_key
  end

  context 'when the method is index' do
    it_behaves_like 'a cop that validates explicit names are added to the index', :index
  end

  context 'when the method is primary_key' do
    it_behaves_like 'a cop that validates explicit names are added to the index', :primary_key
  end

  context 'when the method is full_text_index' do
    it_behaves_like 'a cop that validates explicit names are added to the index', :full_text_index
  end

  context 'when the method is spatial_index' do
    it_behaves_like 'a cop that validates explicit names are added to the index', :spatial_index
  end

  context 'when the method is add_column' do
    it_behaves_like 'a cop that validates explicit names are used when adding a column with an index', :add_column
  end

  context 'when the method is column' do
    it_behaves_like 'a cop that validates explicit names are used when adding a column with an index', :column
  end

  context 'when the method is String' do
    it_behaves_like 'a cop that validates explicit names are used when adding a column with an index', :String
  end

  context 'when the method is Integer' do
    it_behaves_like 'a cop that validates explicit names are used when adding a column with an index', :Integer
  end
end
