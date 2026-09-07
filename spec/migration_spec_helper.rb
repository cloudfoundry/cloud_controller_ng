require 'rubygems'
require 'bundler/setup'
require 'tmpdir'
require 'fileutils'

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start
end

$LOAD_PATH.push(File.expand_path(File.join(__dir__, '..', 'app')))
$LOAD_PATH.push(File.expand_path(File.join(__dir__, '..', 'lib')))

ENV['BOOTSNAP_CACHE_DIR'] ||= File.expand_path('../tmp/bootsnap-cache', __dir__)
require 'bootsnap/setup'
require 'active_support/all'
require 'steno/steno'
require 'sequel/plugins/microsecond_timestamp_precision'

module VCAP
  module CloudController
    # Stub Config so migrations that call Config.config&.get(...) don't fail.
    # The safe-navigation operator (&.) means nil is fine here.
    class Config
      def self.config
        nil
      end

      def get(*_args); end
    end
  end
end

require 'cloud_controller/db'
Sequel.default_timezone = :utc
require 'cloud_controller/db_migrator'
require 'cloud_controller/database_parts_parser'
require 'support/bootstrap/db_connection_string'
require 'support/table_truncator'
require 'support/referential_integrity'
require 'support/matchers/be_a_guid'
require 'support/matchers/have_queried_db_times'
require 'support/and_record_arguments'

# Establish DB connection (sets Sequel::Model.db) without loading CC models.
connection_string = DbConnectionString.new.to_s
db_config = {
  database: VCAP::CloudController::DatabasePartsParser.database_parts_from_connection(connection_string),
  pool_timeout: 10,
  read_timeout: 3600,
  connection_validation_timeout: 3600,
  max_connections: 42
}
VCAP::CloudController::DB.connect(db_config, Logger.new(nil))
Sequel.extension :migration

# Lightweight truncation that skips seed re-seeding (migration specs don't use seeds).
module MigrationSpecTruncation
  WRITE_REGEX = /\b(?:INSERT INTO|UPDATE|DELETE FROM|TRUNCATE TABLE|TRUNCATE)\s+(\S+)/i

  def self.cleanly(db)
    tables_written = Set.new

    logger = Object.new
    %i[info warn debug error fatal].each do |level|
      logger.define_singleton_method(level) { |msg| MigrationSpecTruncation.capture(msg, tables_written) }
    end

    db.loggers << logger
    begin
      yield
    ensure
      db.loggers.delete(logger)
      all_tables = TableTruncator.isolated_tables(db)
      tables = tables_written.to_a & all_tables
      TableTruncator.new(db, tables).truncate_tables unless tables.empty?
    end
  end

  def self.capture(msg, tables_written)
    return unless msg =~ WRITE_REGEX

    target = ::Regexp.last_match(1).delete('`"')
    tables_written << target.to_sym unless target.include?('.')
  end
end

RSpec.configure do |config|
  config.before(:all, type: :migration) do
    skip 'Skipped due to NO_DB_MIGRATION env variable being set' if ENV['NO_DB_MIGRATION']
  end

  config.around(type: :migration) do |example|
    if example.metadata[:isolation] == :truncation
      MigrationSpecTruncation.cleanly(Sequel::Model.db) { example.run }
    else
      Sequel::Model.db.transaction(rollback: :always, auto_savepoint: true) { example.run }
    end
  end
end
