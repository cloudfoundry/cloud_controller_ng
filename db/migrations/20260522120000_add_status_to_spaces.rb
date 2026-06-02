Sequel.migration do
  up do
    alter_table :spaces do
      add_column :status, String, null: false, default: 'active', size: 255 unless @db.schema(:spaces).map(&:first).include?(:status)
    end
  end

  down do
    alter_table :spaces do
      drop_column :status if @db.schema(:spaces).map(&:first).include?(:status)
    end
  end
end
