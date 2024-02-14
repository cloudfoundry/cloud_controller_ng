ForeignKey = Struct.new(:table, :name, :column, :referenced_table, :referenced_column, :new_constraint) do
  def initialize(table, name, column, referenced_table, referenced_column, new_constraint: false)
    super(table, name, column, referenced_table, referenced_column, new_constraint)
  end
end

def foreign_key_exists?(db, table, name)
  db.foreign_key_list(table).detect { |fk| fk[:name] == name }.present?
end

def recreate_foreign_key_with_delete_cascade(db, fkey)
  # Remove orphaned entries.
  db[fkey.table].exclude(fkey.column => db[fkey.referenced_table].select(fkey.referenced_column)).delete if fkey.new_constraint

  alter_table fkey.table do
    drop_constraint fkey.name, type: :foreign_key if foreign_key_exists?(db, fkey.table, fkey.name)
    add_foreign_key [fkey.column], fkey.referenced_table, key: fkey.referenced_column, name: fkey.name, on_delete: :cascade
  end
end

def recreate_foreign_key_without_delete_cascade(db, fkey)
  alter_table fkey.table do
    drop_constraint fkey.name, type: :foreign_key if foreign_key_exists?(db, fkey.table, fkey.name)
    add_foreign_key [fkey.column], fkey.referenced_table, key: fkey.referenced_column, name: fkey.name unless fkey.new_constraint
  end
end
