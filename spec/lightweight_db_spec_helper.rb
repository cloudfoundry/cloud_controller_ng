require 'lightweight_spec_helper'
require 'sequel'
require 'support/bootstrap/db_connection_string'

DB = Sequel.connect(DbConnectionString.new.to_s)
