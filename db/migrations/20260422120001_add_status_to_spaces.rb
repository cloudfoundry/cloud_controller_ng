Sequel.migration do
  no_transaction

  up do
    if database_type == :postgres
      add_column :spaces, :status, String, size: 255, default: 'active', if_not_exists: true
    elsif database_type == :mysql
      alter_table :spaces do
        add_column :status, String, size: 255, default: 'active' unless @db.schema(:spaces).map(&:first).include?(:status)
      end
    end
  end

  down do
    if database_type == :postgres
      drop_column :spaces, :status, if_exists: true
    elsif database_type == :mysql
      alter_table :spaces do
        drop_column :status if @db.schema(:spaces).map(&:first).include?(:status)
      end
    end
  end
end
