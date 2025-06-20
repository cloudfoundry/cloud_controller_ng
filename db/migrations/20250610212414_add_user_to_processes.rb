Sequel.migration do
  up do
    alter_table :processes do
      add_column :user, String, null: true, default: nil, size: 255 unless @db.schema(:processes).map(&:first).include?(:user)
    end
  end

  down do
    alter_table :processes do
      drop_column :user if @db.schema(:processes).map(&:first).include?(:user)
    end
  end
end
