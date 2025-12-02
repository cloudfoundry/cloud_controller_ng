# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Sequel::ConcurrentIndex do
  include Spec::Helpers::Migration

  subject(:cop) { described_class.new }

  context 'without the concurrent option' do
    it 'registers an offense without options' do
      offenses = inspect_source_within_migration(<<~SOURCE)
        add_index(:products, :name)
        drop_index(:products, :name)
      SOURCE
      expect(offenses.size).to eq(2)
    end

    it 'registers an offense with other options' do
      offenses = inspect_source_within_migration(<<~SOURCE)
        add_index(:products, :name, unique: true)
        drop_index(:products, :name, unique: true)
      SOURCE
      expect(offenses.size).to eq(2)
    end

    it 'registers an offense with composite index' do
      offenses = inspect_source_within_migration(<<~SOURCE)
        add_index(:products, [:name, :price], unique: true)
        drop_index(:products, [:name, :price])
      SOURCE
      expect(offenses.size).to eq(2)
    end
  end

  it 'does not register an offense when using concurrent option' do
    offenses = inspect_source_within_migration(<<~SOURCE)
      add_index(:products, :name, unique: true, concurrently: true)
      drop_index(:products, :name, concurrently: true)
    SOURCE
    expect(offenses).to be_empty
  end
end
