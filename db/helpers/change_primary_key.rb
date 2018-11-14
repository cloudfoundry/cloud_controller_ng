require 'pry'

# has_primary_key
# postgres supports `db.primary_key`, mysql doesn't, so fall back to
# analyzing the schema.
def has_primary_key(db, table, key)
  return db.primary_key(table) == key.to_s if db.respond_to?(:primary_key)

  pk_column_info = db.schema(table).find { |column_info| column_info[0] == key }
  return false if pk_column_info.nil?

  pk_column_info[1][:primary_key] == true
end

def add_primary_key_to_table(table, key)
  db = self
  unless has_primary_key(db, table, key)
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
