Sequel.migration do
  up do
    alter_table :stacks do
      add_column :state_reason, String, null: true, size: 1000 unless @db.schema(:stacks).map(&:first).include?(:state_reason)
    end
  end

  down do
    alter_table :stacks do
      drop_column :state_reason if @db.schema(:stacks).map(&:first).include?(:state_reason)
    end
  end
end
