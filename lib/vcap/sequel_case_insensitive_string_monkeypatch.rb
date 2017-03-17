require 'sequel'
require 'sequel/adapters/postgres'
require 'sequel/adapters/mysql2'
require 'sequel/adapters/tinytds'

# Add :case_insensitive as an option to the string type during migrations.
# This results in case insensitive comparisions for indexing and querying, but
# case preserving retrieval.
#
# This is probably not the best way of doing this, and it would probably be
# "cleanest" to figure out how to make a new datatype using a Sequel plugin,
# but it wasn't immediately obvious how to wrap a type definition such that we
# could inject the necessary collation option when necessary (for sqlite)...
# and this works.
#
# To use this in a migration do the following:
#
# Sequel.migration do
#   change do
#     create_table :foo do
#       String :name, :case_insensitive => true
#       String :base64_data
#     end
#   end
# end
#
# In the above migration, name will will have case insensitive comparisions,
# but case preserving data, whereas base64_data will be case sensitive.

Sequel::Postgres::Database.class_eval do
  def case_insensitive_string_column_type
    'CIText'
  end

  def case_insensitive_string_column_opts
    {}
  end
end

Sequel::Mysql2::Database.class_eval do
  # Mysql is case insensitive by default

  def case_insensitive_string_column_type
    'VARCHAR(255)'
  end

  def case_insensitive_string_column_opts
    { collate: 'utf8_general_ci' }
  end
end

Sequel::MSSQL::DatabaseMethods.class_eval do
  # TODO: PR a fix to Sequel library
  def foreign_key_list(table, opts=Sequel::OPTS)
    m = output_identifier_meth
    im = input_identifier_meth
    schema, table = schema_and_table(table)
    current_schema = m.call(get(Sequel.function('schema_name')))
    fk_action_map = Sequel::MSSQL::DatabaseMethods::FOREIGN_KEY_ACTION_MAP
    fk = Sequel[:fk]
    fkc = Sequel[:fkc]
    ds = metadata_dataset.from(Sequel.lit('[sys].[foreign_keys]').as(:fk)).
      join(Sequel.lit('[sys].[foreign_key_columns]').as(:fkc), :constraint_object_id => :object_id).
      join(Sequel.lit('[sys].[all_columns]').as(:pc), :object_id => fkc[:parent_object_id],     :column_id => fkc[:parent_column_id]).
      join(Sequel.lit('[sys].[all_columns]').as(:rc), :object_id => fkc[:referenced_object_id], :column_id => fkc[:referenced_column_id]).
      # original implementation returned `DBO` when it should have returned `dbo`:
      # where{{object_schema_name(fk[:parent_object_id]) => im.call(schema || current_schema)}}.
      where{{object_schema_name(fk[:parent_object_id]) => (schema || current_schema).to_s}}.
      where{{object_name(fk[:parent_object_id]) => im.call(table)}}.
      select{[fk[:name],
      fk[:delete_referential_action],
      fk[:update_referential_action],
      pc[:name].as(:column),
      rc[:name].as(:referenced_column),
      object_schema_name(fk[:referenced_object_id]).as(:schema),
      object_name(fk[:referenced_object_id]).as(:table)]}.
      order(fk[:name], fkc[:constraint_column_id])
    h = {}
    ds.each do |row|
      if r = h[row[:name]]
        r[:columns] << m.call(row[:column])
        r[:key] << m.call(row[:referenced_column])
      else
        referenced_schema = m.call(row[:schema])
        referenced_table = m.call(row[:table])
        h[row[:name]] = { :name      => m.call(row[:name]),
          :table     => (referenced_schema == current_schema) ? referenced_table : Sequel.qualify(referenced_schema, referenced_table),
          :columns   => [m.call(row[:column])],
          :key       => [m.call(row[:referenced_column])],
          :on_update => fk_action_map[row[:update_referential_action]],
          :on_delete => fk_action_map[row[:delete_referential_action]] }
      end
    end
    h.values
  end

  def default_constraint_name(table, column_name)
    # TODO: PR this change back to Sequel
    if server_version >= 9000000
      table_name = schema_and_table(table).compact.join('.')
      metadata_dataset.from(Sequel.lit('[sys].[default_constraints]')).
        where{{:parent_object_id => Sequel::SQL::Function.new(:object_id, table_name.upcase), col_name(:parent_object_id, :parent_column_id) => column_name.to_s.upcase}}.
        get(:name)
    end
  end
end

Sequel::TinyTDS::Database.class_eval do
  # Migrations set SQL Server DB Collation to be case sensitive by default

  def case_insensitive_string_column_type
    'VARCHAR(255)'
  end

  def case_insensitive_string_column_opts
    { collate: 'SQL_Latin1_General_CP1_CI_AS' }
  end
end

Sequel::Schema::Generator.class_eval do
  # rubocop:disable Style/MethodName
  def String(name, opts={})
    if opts[:case_insensitive]
      unless @db.respond_to?(:case_insensitive_string_column_type)
        raise Error.new('DB adapater does not support case insensitive strings')
      end

      column(
        name,
        @db.case_insensitive_string_column_type,
        opts.merge(@db.case_insensitive_string_column_opts)
      )
    else
      column(name, String, opts)
    end
  end
  # rubocop:enable Style/MethodName
end

Sequel::Schema::AlterTableGenerator.class_eval do
  alias_method :set_column_type_original, :set_column_type

  def set_column_type(name, type, opts={})
    if type.to_s == 'String' && opts[:case_insensitive]
      unless @db.respond_to?(:case_insensitive_string_column_type)
        raise Error.new('DB adapater does not support case insensitive strings')
      end

      set_column_type_original(
        name,
        @db.case_insensitive_string_column_type,
        opts.merge(@db.case_insensitive_string_column_opts)
      )
    else
      set_column_type_original(name, type, opts)
    end
  end
end
