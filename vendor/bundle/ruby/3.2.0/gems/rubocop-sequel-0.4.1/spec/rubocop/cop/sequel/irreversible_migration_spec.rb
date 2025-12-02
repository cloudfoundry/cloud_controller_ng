# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Sequel::IrreversibleMigration do
  include Spec::Helpers::Migration

  subject(:cop) { described_class.new }

  context 'when inside a change block' do
    let(:invalid_source) do
      <<~SOURCE
        change do
          alter_table(:stores) do
            drop_column(:products, :name)
            drop_index(:products, :price)
          end
        end
      SOURCE
    end

    let(:valid_source) do
      <<~SOURCE
        change do
          alter_table(:stores) do
            add_primary_key(:id)
            add_column(:products, :name)
            add_index(:products, :price)
          end
        end
      SOURCE
    end

    it 'registers an offense when there is an invalid method' do
      offenses = inspect_source_within_migration(invalid_source)
      expect(offenses.size).to eq(2)
    end

    it 'does not register an offense with valid methods' do
      offenses = inspect_source_within_migration(valid_source)
      expect(offenses).to be_empty
    end

    describe 'and using a create_table block' do
      let(:source) do
        <<~SOURCE
          change do
            create_table(:artists) do
              primary_key :id
              String :name, null: false
            end
          end
        SOURCE
      end

      it 'does not register any offenses' do
        offenses = inspect_source_within_migration(source)
        expect(offenses).to be_empty
      end
    end

    describe 'and using a create_table block and alter_table block' do
      let(:source) do
        <<~SOURCE
          change do
            alter_table(:stores) do
              drop_column(:products, :name)
              drop_index(:products, :price)
            end

            add_column :books, :name, String

            create_table(:artists) do
              primary_key :id
              String :name, null: false
            end
          end
        SOURCE
      end
      let(:expected_methods) { %w[drop_column drop_index] }

      it 'only registers offenses from within alter_table block' do
        messages = inspect_source_within_migration(source).map(&:message)
        expected_methods_present = expected_methods.all? do |method|
          messages.any? { |message| message.include?(method) }
        end

        expect(expected_methods_present).to be(true)
      end
    end

    describe 'and an array is passed into `add_primary_key`' do
      let(:source) do
        <<~SOURCE
          change do
            alter_table(:stores) do
              add_primary_key([:owner_id, :name])
            end
          end
        SOURCE
      end

      it 'registers an offense' do
        offenses = inspect_source_within_migration(source)
        expect(offenses.size).to eq(1)
      end
    end

    describe 'and a method is used within an argument' do
      let(:source) do
        <<~SOURCE
          change do
            alter_table(:stores) do
              add_column(:products, JSON, null: false, default: Sequel.pg_json({}))
              add_constraint(
                :only_one_user,
                (
                  Sequel.cast(Sequel.~(user_id: nil), Integer) +
                  Sequel.cast(Sequel.~(owner_id: nil), Integer)
                ) => 1,
              )
            end
          end
        SOURCE
      end

      it 'does not register an offense with valid methods' do
        offenses = inspect_source_within_migration(source)
        expect(offenses).to be_empty
      end
    end

    describe 'and an invalid change method contains another invalid change method as an argument' do
      let(:source) do
        <<~SOURCE
          change do
            alter_table(:stores) do
              drop_column(:products, JSON, null: false, default: Sequel.pg_json({}))
            end
          end
        SOURCE
      end

      it 'only registers 1 offense' do
        offenses = inspect_source_within_migration(source)
        expect(offenses.size).to eq(1)
      end

      it 'only registers an offense for the parent method' do
        offenses = inspect_source_within_migration(source)
        expect(offenses.first.message).to include('drop_column')
      end
    end
  end

  context 'when inside an up block' do
    let(:source) do
      <<~SOURCE
        up do
          alter_table(:stores) do
            add_primary_key([:owner_id, :name])
            add_column(:products, :name)
            drop_index(:products, :price)
          end
        end
      SOURCE
    end

    it 'does not register an offense with any methods' do
      offenses = inspect_source_within_migration(source)
      expect(offenses).to be_empty
    end
  end

  context 'when a change block is used outside of a Sequel migration' do
    let(:source) do
      <<~SOURCE
        it { expect { subject }.to change { document_count(user_id) }.by(-1) }
      SOURCE
    end

    it 'does not register an offense with any methods' do
      offenses = inspect_source(source)
      expect(offenses).to be_empty
    end
  end
end
