# Copyright (c) 2009-2012 VMware, Inc.

require "sequel"
require "sequel/adapters/sqlite"

module VCAP::Sequel::SQLite
  def self.monkey_patch
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

    def self.validate_sqlite_version(db)
      return if @validated_sqlite
      @validate_sqlite = true

      min_version = "3.6.19"
      version = db.fetch("SELECT sqlite_version()").first[:"sqlite_version()"]
      unless validate_version_string(min_version, version)
        puts <<EOF
The CC models require sqlite version >= #{min_version} but you are
running #{version} On OSX, you will might to install the sqlite
gem against an upgraded sqlite (from source, homebrew, macports, etc)
and not the system sqlite. You can do so with a command
such as:

  gem install sqlite3 -- --with-sqlite3-include=/usr/local/include/ \
                         --with-sqlite3-lib=/usr/local/lib

EOF
        exit 1
      end
    end

    def self.validate_version_string(min_version, version)
      min_fields = min_version.split(".").map { |v| v.to_i }
      ver_fields = version.split(".").map { |v| v.to_i }

      (0..2).each do |i|
        return true  if ver_fields[i] > min_fields[i]
        return false if ver_fields[i] < min_fields[i]
      end

      return true
    end
  end
end

VCAP::SQLite.monkey_patch
VCAP::SQLite.validate_sqlite_version
