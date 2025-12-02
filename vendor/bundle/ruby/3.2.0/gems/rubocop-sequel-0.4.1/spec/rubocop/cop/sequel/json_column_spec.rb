# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Sequel::JSONColumn do
  include Spec::Helpers::Migration

  subject(:cop) { described_class.new }

  context 'with add_column' do
    it 'registers an offense when using json type' do
      offenses = inspect_source_within_migration('add_column(:products, :type, :json)')
      expect(offenses.size).to eq(1)
    end

    it 'registers an offense when using hstore type' do
      offenses = inspect_source_within_migration('add_column(:products, :type, :hstore)')
      expect(offenses.size).to eq(1)
    end

    it 'does not register an offense when using jsonb' do
      offenses = inspect_source_within_migration('add_column(:products, :type, :jsonb)')
      expect(offenses).to be_empty
    end
  end

  context 'with create_table' do
    it 'registers an offense when using json as a method' do
      offenses = inspect_source_within_migration('create_table(:products) { json :type, default: {} }')
      expect(offenses.size).to eq(1)
    end

    it 'registers an offense when using the column method with hstore' do
      offenses = inspect_source_within_migration('create_table(:products) { column :type, :hstore }')
      expect(offenses.size).to eq(1)
    end

    it 'does not register an offense when using jsonb as column type`' do
      offenses = inspect_source_within_migration('create_table(:products) { column :type, :jsonb }')
      expect(offenses).to be_empty
    end

    it 'does not register an offense when using jsonb' do
      offenses = inspect_source_within_migration('create_table(:products) { jsonb :type }')
      expect(offenses).to be_empty
    end

    it 'does not register an offense when using a simple type' do
      offenses = inspect_source_within_migration('create_table(:products) { integer :type, default: 0 }')
      expect(offenses).to be_empty
    end
  end
end
