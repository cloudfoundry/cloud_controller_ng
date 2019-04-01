Sequel.migration do
  # rubocop:disable Lint/BooleanSymbol
  change do
    create_table :isolation_segments do
      VCAP::Migration.common(self)
      String :name, null: false, case_insensitive: :true
      index :name
    end

    alter_table :isolation_segments do
      add_unique_constraint :name, name: :isolation_segment_name_unique_constraint
    end
  end
  # rubocop:enable Lint/BooleanSymbol
end
