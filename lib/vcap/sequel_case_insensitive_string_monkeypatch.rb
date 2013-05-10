# Copyright (c) 2009-2012 VMware, Inc.

require "sequel"
require "sequel/adapters/sqlite"
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

Sequel::Database.class_eval do
  def use_lower_where?
    true
  end
  def use_lower_index?
    false
  end
end

Sequel::SQLite::Database.class_eval do
  def case_insensitive_string_column_type
    "String"
  end

  def case_insensitive_string_column_opts
    { :collate => :nocase }
  end
  
  def use_lower_where?
    true
  end
  def use_lower_index?
    false
  end
end

Sequel::Postgres::Database.class_eval do
  def case_insensitive_string_column_type
    "CIText"
  end

  def case_insensitive_string_column_opts
    {}
  end
  def use_lower_where?
    false
  end
  def use_lower_index?
    false
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
  def use_lower_where?
    false
  end

  def use_lower_index?
    false
  end
end

begin
  gem "ruby-oci8"
  require "sequel/adapters/oracle"  
  Sequel::Oracle::Database.class_eval do
    def case_insensitive_string_column_type
      "VARCHAR2(255)"
    end
  
    def case_insensitive_string_column_opts
      { }
    end
    
    def use_lower_where?
      true
    end
    
    def use_lower_index?
      true
    end
  end
rescue Gem::LoadError
  # not installed
end


Sequel::Schema::Generator.class_eval do
  alias_method :index_original, :index
  
  def String(name, opts = {})
    if opts[:case_insensitive]
      unless @db.respond_to?(:case_insensitive_string_column_type)
        raise Sequel::Error, "DB adapter does not support case insensitive strings"
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
  
  def index(columns, opts = {})
    columns = [columns] unless columns.kind_of?(Array)
    if opts[:case_insensitive] && @db.use_lower_index?
      columns.map! { |column|
        unless opts[:case_insensitive].kind_of?(Array) && !opts[:case_insensitive].include?(column)
          column = Sequel.function(:lower, column)
        end
        column 
      }
    end
    index_original(columns, opts)
  end
end

Sequel::Schema::AlterTableGenerator.class_eval do
  alias_method :set_column_type_original, :set_column_type
  alias_method :add_index_original, :add_index

  def set_column_type(name, type, opts = {})
    if type.to_s == "String" && opts[:case_insensitive]
      unless @db.respond_to?(:case_insensitive_string_column_type)
        raise Sequel::Error, "DB adapter does not support case insensitive strings"
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

  def add_index(columns, opts={})
    columns = [columns] unless columns.kind_of?(Array)
    if opts[:case_insensitive] && @db.use_lower_index?
      columns.map! { |column|
        unless opts[:case_insensitive].kind_of?(Array) && !opts[:case_insensitive].include?(column)
          column = Sequel.function(:lower, column)
				end        
				column 
      }
    end
    add_index_original(columns, opts)
  end
end
