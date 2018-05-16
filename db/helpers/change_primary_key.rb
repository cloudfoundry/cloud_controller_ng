def add_primary_key_to_table(table, key)
  db = self

  unless db.primary_key(table) == key.to_s
    alter_table table do
      add_primary_key :id, name: key
    end
  end
end

def remove_primary_key_from_table(table, key, column)
  alter_table table do
    drop_constraint(key)
    drop_column(column)
  end
end
