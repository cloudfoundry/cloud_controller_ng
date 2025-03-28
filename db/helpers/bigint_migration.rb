require 'tasks/rake_config'

# helpers
def opt_out?
  opt_out = RakeConfig.config.get(:skip_bigint_id_migration)
  opt_out.nil? ? false : opt_out
rescue VCAP::CloudController::Config::InvalidConfigPath
  false
end

# DSL
def empty?(table)
  raise unless is_a?(Sequel::Database)

  self[table].count == 0
end

def change_pk_to_bigint(table)
  raise unless is_a?(Sequel::Database)

  set_column_type(table, :id, :Bignum) if column_type(self, table, :id) != BIGINT_TYPE
end

def add_bigint_column(table)
  raise unless is_a?(Sequel::Database)

  add_column(table, :id_bigint, :Bignum, if_not_exists: true)
end

def revert_pk_to_integer(table)
  raise unless is_a?(Sequel::Database)

  set_column_type(table, :id, :integer) if column_type(self, table, :id) == BIGINT_TYPE
end

def drop_bigint_column(table)
  raise unless is_a?(Sequel::Database)

  drop_column(table, :id_bigint, if_exists: true)
end

# internal constants
BIGINT_TYPE = 'bigint'.freeze

# internal helpers
def column_type(db, table, column)
  db.schema(table).find { |col, _| col == column }&.dig(1, :db_type)
end
