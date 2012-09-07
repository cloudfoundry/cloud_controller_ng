# Copyright (c) 2009-2012 VMware, Inc.

# Add :case_insensitive as an option to the string type during migrations.
# This results in case insensitive comparisions for indexing and querying, but
# case preserving retreaval.
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

module Sequel
  module SQLite
    class Database
      def case_insensitive_string_column_type
        "String"
      end

      def case_insensitive_string_column_opts
        { :collate => :nocase }
      end
    end
  end
end

module Sequel
  module Postgres
    module Database
      def case_insensitive_string_column_type
        "CIText"
      end

      def case_insensitive_string_column_opts
        {}
      end
    end
  end
end

module Sequel
  module Schema
    class Generator
      def String(name, opts = {})
        if opts[:case_insensitive]
          unless @db.respond_to?(:case_insensitive_string_column_type)
            raise Error, "DB adapater does not support case insensitive strings"
          end

          column(name, @db.case_insensitive_string_column_type,
                 opts.merge(@db.case_insensitive_string_column_opts))
        else
          column(name, String, opts)
        end
      end
    end
  end
end
