require "sequel"
require "sequel/adapters/postgres"
require "sequel/adapters/mysql2"

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
    "CIText"
  end

  def case_insensitive_string_column_opts
    {}
  end
end

Sequel::Mysql2::Database.class_eval do
  # Mysql is case insensitive by default
  def case_insensitive_string_column_type
    "VARCHAR(255)"
  end

  def case_insensitive_string_column_opts
    { :collate => "latin1_general_ci" }
  end
end

Sequel::Schema::Generator.class_eval do
  def String(name, opts = {})
    if opts[:case_insensitive]
      unless @db.respond_to?(:case_insensitive_string_column_type)
        raise Error, "DB adapater does not support case insensitive strings"
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
end

Sequel::Schema::AlterTableGenerator.class_eval do
  alias_method :set_column_type_original, :set_column_type

  def set_column_type(name, type, opts = {})
    if type.to_s == "String" && opts[:case_insensitive]
      unless @db.respond_to?(:case_insensitive_string_column_type)
        raise Error, "DB adapater does not support case insensitive strings"
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
