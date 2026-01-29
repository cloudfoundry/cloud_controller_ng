Sequel.migration do
  up do
    alter_table :stacks do
      add_column :state, String, null: false, default: 'ACTIVE', size: 255 unless @db.schema(:stacks).map(&:first).include?(:state)
    end
  end

  down do
    alter_table :stacks do
      drop_column :state if @db.schema(:stacks).map(&:first).include?(:state)
    end
  end
end
