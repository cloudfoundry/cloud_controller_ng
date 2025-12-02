# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Sequel::MigrationName, :config do
  subject(:cop) { described_class.new(config) }

  let(:config) do
    RuboCop::Config.new(
      { 'AllCops' => { 'Include' => [] },
        'Sequel/MigrationName' => cop_config },
      '/some/.rubocop.yml'
    )
  end

  context 'with default configuration' do
    let(:cop_config) { {} }

    it 'registers an offense when using the default name' do
      offenses = inspect_source('', 'new_migration.rb')
      expect(offenses.size).to eq(1)
    end

    it 'does not register an offense when using a specific name' do
      offenses = inspect_source('', 'add_index.rb')
      expect(offenses).to be_empty
    end
  end

  context 'with custom configuration' do
    let(:cop_config) { { 'DefaultName' => 'add_migration' } }

    it 'registers an offense when using the default name' do
      offenses = inspect_source('', 'add_migration.rb')
      expect(offenses.size).to eq(1)
    end

    it 'does not register an offense when using a specific name' do
      offenses = inspect_source('', 'add_index.rb')
      expect(offenses).to be_empty
    end
  end
end
