# Copyright (c) 2009-2012 VMware, Inc.

require "sequel"
require "sequel/adapters/sqlite"

Sequel::SQLite::Database.class_eval do
  def connect(server)
    opts = server_opts(server)
    opts[:database] = ":memory:" if blank_object?(opts[:database])
    db = ::SQLite3::Database.new(opts[:database])
    db.busy_handler do |retries|
      Steno.logger("db.patch").debug "SQLITE BUSY, retry ##{retries}"
      sleep(0.1)
      retries < 20
    end

    connection_pragmas.each { |s| log_yield(s) { db.execute_batch(s) } }

    class << db
      attr_reader :prepared_statements
    end
    db.instance_variable_set(:@prepared_statements, {})
    db
  end
end
