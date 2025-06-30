Sequel.migration do
  up do
    alter_table :tasks do
      add_column :user, String, null: true, default: nil, size: 255 unless @db.schema(:tasks).map(&:first).include?(:user)
    end
  end

  down do
    alter_table :tasks do
      drop_column :user if @db.schema(:tasks).map(&:first).include?(:user)
    end
  end
end
