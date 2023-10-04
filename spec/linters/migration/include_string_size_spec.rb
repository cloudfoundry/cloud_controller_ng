require 'spec_helper'
require 'rubocop'
require 'rubocop/rspec/cop_helper'
require 'rubocop/config'
require 'linters/migration/include_string_size'

RSpec.describe RuboCop::Cop::Migration::IncludeStringSize do
  include CopHelper

  subject(:cop) { RuboCop::Cop::Migration::IncludeStringSize.new(RuboCop::Config.new({})) }

  let(:string_size_message) do
    'Please specify an explicit size for String columns. `size: 255` is a good size for small strings, `size: 16_000` is the maximum for UTF8 strings.'
  end
  let(:string_text_message) do
    'Considering using string with an appropriate size rather than `text: true`. The size of `text: true` depends on MySQL vs Postgres'
  end

  RSpec.shared_examples 'a cop that validates inclusion of string size' do |method_name|
    context 'with an explicit table name' do
      it 'registers an offense if string column is added without a specified size' do
        inspect_source(<<~RUBY)
          change do
            #{method_name} :carly, :my_column, String
          end
        RUBY

        expect(cop.offenses.size).to eq(1)
        expect(cop.messages).to eq([string_size_message])
      end

      it 'does not register an offense if string has a size' do
        inspect_source(<<~RUBY)
          change do
            #{method_name} :rae, :my_column, String, size: 1
          end
        RUBY

        expect(cop.offenses.size).to eq(0)
        expect(cop.messages).to be_empty
      end

      it 'does not register an offense if string has a size' do
        inspect_source(<<~RUBY)
          change do
            #{method_name} :jepsen, :my_column, Integer
          end
        RUBY

        expect(cop.offenses.size).to eq(0)
        expect(cop.messages).to be_empty
      end

      it 'registers an offense if string column is added without a specified size' do
        inspect_source(<<~RUBY)
          change do
            #{method_name} :call, :my_column, String, text: true, size: 1
          end
        RUBY

        expect(cop.offenses.size).to eq(1)
        expect(cop.messages).to eq([string_text_message])
      end
    end

    context 'with an implicit table name' do
      it 'registers an offense if string column is added without a specified size' do
        inspect_source(<<~RUBY)
          create_table :jobs do
            #{method_name} :my_column, String
          end
        RUBY

        expect(cop.offenses.size).to eq(1)
        expect(cop.messages).to eq([string_size_message])
      end

      it 'does not register an offense if string has a size' do
        inspect_source(<<~RUBY)
          create_table :jobs do
            #{method_name} :my_column, String, size: 1
          end
        RUBY

        expect(cop.offenses.size).to eq(0)
        expect(cop.messages).to be_empty
      end

      it 'does not register an offense if string has a size' do
        inspect_source(<<~RUBY)
          create_table :jobs do
            #{method_name} :other_column, Integer
          end
        RUBY

        expect(cop.offenses.size).to eq(0)
        expect(cop.messages).to be_empty
      end
    end
  end

  context 'when the method is add_column' do
    it_behaves_like 'a cop that validates inclusion of string size', :add_column
  end

  context 'when the method is set_column_type' do
    it_behaves_like 'a cop that validates inclusion of string size', :set_column_type
  end

  context 'when the table is being created' do
    it 'registers an offense if string column is added without a specified size' do
      inspect_source(<<~RUBY)
        create_table :jobs do
          String :my_column
        end
      RUBY

      expect(cop.offenses.size).to eq(1)
      expect(cop.messages).to eq([string_size_message])
    end

    it 'does not register an offense if string has a size' do
      inspect_source(<<~RUBY)
        create_table :jobs do
          String :my_column, size: 1
        end
      RUBY

      expect(cop.offenses.size).to eq(0)
      expect(cop.messages).to be_empty
    end

    it 'does not register an offense for non-string declarations' do
      inspect_source(<<~RUBY)
        create_table :jobs do
          Integer :my_column
        end
      RUBY

      expect(cop.offenses.size).to eq(0)
      expect(cop.messages).to be_empty
    end
  end
end
