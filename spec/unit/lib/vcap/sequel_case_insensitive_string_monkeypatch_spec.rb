require 'spec_helper'
require 'vcap/sequel_case_insensitive_string_monkeypatch'

RSpec.describe 'String :name' do
  let(:table_name) { :unique_str_defaults }
  let(:db_config) { DbConfig.new }

  context 'with default options' do
    before do
      @c = Class.new(Sequel::Model)
      @c.set_dataset(db_config.connection[table_name])
      @c.create(str: 'abc')
    end

    it 'should allow create with different case' do
      expect(@c.create(str: 'ABC')).to be_valid
    end

    it 'should perform case sensitive search' do
      expect(@c.dataset[str: 'abc']).not_to be_nil
      expect(@c.dataset[str: 'aBC']).to be_nil
    end
  end

  context 'with :case_insensitive => false' do
    let(:table_name) { :unique_str_case_sensitive }

    before do
      @c = Class.new(Sequel::Model)
      @c.set_dataset(db_config.connection[table_name])
      @c.create(str: 'abc')
    end

    it 'should allow create with different case' do
      expect(@c.create(str: 'ABC')).to be_valid
    end

    it 'should perform case sensitive search' do
      expect(@c.dataset[str: 'abc']).not_to be_nil
      expect(@c.dataset[str: 'aBC']).to be_nil
    end
  end

  context 'with :case_insensitive => true' do
    let(:table_name) { :unique_str_case_insensitive }

    before do
      @c = Class.new(Sequel::Model) do
        def validate
          validates_unique :str
        end
      end
      @c.set_dataset(db_config.connection[table_name])
      @c.create(str: 'abc')
    end

    it 'should not allow create with different case due to sequel validations' do
      expect {
        @c.create(str: 'ABC')
      }.to raise_error(Sequel::ValidationFailed)
    end

    it 'should not allow create with different case due to db constraints' do
      expect {
        @c.new(str: 'ABC').save(validate: false)
      }.to raise_error(Sequel::DatabaseError)
    end

    it 'should perform case sensitive search' do
      expect(@c.dataset[str: 'abc']).not_to be_nil
      expect(@c.dataset[str: 'aBC']).not_to be_nil
    end
  end

  context 'alter table set_column_type' do
    let(:table_name) { :unique_str_altered }

    context 'with defaults' do
      it 'should not result in a case sensitive column' do
        @c = Class.new(Sequel::Model)
        @c.set_dataset(db_config.connection[table_name])
        @c.create(altered_to_default: 'abc')
        expect(@c.dataset[altered_to_default: 'abc']).not_to be_nil
        expect(@c.dataset[altered_to_default: 'ABC']).to be_nil
      end
    end

    context 'with :case_insensitive => false' do
      it 'should not result in a case sensitive column' do
        @c = Class.new(Sequel::Model)
        @c.set_dataset(db_config.connection[table_name])
        @c.create(altered_to_case_sensitive: 'abc')
        expect(@c.dataset[altered_to_case_sensitive: 'abc']).not_to be_nil
        expect(@c.dataset[altered_to_case_sensitive: 'ABC']).to be_nil
      end
    end

    context 'with :case_insensitive => true' do
      it 'should change the column' do
        @c = Class.new(Sequel::Model)
        @c.set_dataset(db_config.connection[table_name])
        @c.create(altered_to_case_insensitive: 'abc')
        expect(@c.dataset[altered_to_case_insensitive: 'abc']).not_to be_nil
        expect(@c.dataset[altered_to_case_insensitive: 'ABC']).not_to be_nil
      end
    end
  end
end
