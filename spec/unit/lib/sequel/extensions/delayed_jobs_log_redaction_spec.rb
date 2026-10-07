require 'spec_helper'
require 'sequel/extensions/delayed_jobs_log_redaction'

RSpec.describe Sequel::DelayedJobsLogRedaction do
  let(:db_config) { DbConfig.new }
  let(:logs) { StringIO.new }
  let(:logger) { Logger.new(logs) }

  # log_db_queries:true is what makes DB.connect install the redaction extension.
  let(:db) do
    VCAP::CloudController::DB.connect(
      db_config.config.merge(log_db_queries: true, log_level: :info),
      db_config.db_logger
    )
  end

  before do
    db.loggers << logger
    db.sql_log_level = :info
  end

  after { db.disconnect }

  describe 'wiring via DB.connect' do
    it 'installs the redaction extension when log_db_queries is true' do
      expect(db.respond_to?(:redact_delayed_jobs, true)).to be(true)
    end

    it 'does NOT install the redaction extension when log_db_queries is false' do
      plain = VCAP::CloudController::DB.connect(
        db_config.config.merge(log_db_queries: false), db_config.db_logger
      )
      expect(plain.respond_to?(:redact_delayed_jobs, true)).to be(false)
    ensure
      plain&.disconnect
    end
  end

  describe 'redaction of logged SQL' do
    it 'redacts the handler value on INSERT but keeps the table and column name' do
      handler = "--- !ruby/object:VCAP::CloudController::Jobs::LoggingContextJob\n  " \
                "arbitrary_parameters:\n    :systempassword: s3cr3t-value\n"
      sql = %(INSERT INTO "delayed_jobs" ("queue", "handler", "created_at") ) +
            %(VALUES ('cc-generic', '#{handler}', CURRENT_TIMESTAMP))
      db.log_connection_yield(sql, nil) {}

      expect(logs.string).to include('INSERT INTO "delayed_jobs"')
      expect(logs.string).to include('"handler"')
      expect(logs.string).to include('[REDACTED]')
      expect(logs.string).not_to include('s3cr3t-value')
    end

    it 'redacts handlers serialized with a non-object ruby tag (e.g. !ruby/struct)' do
      handler = "--- !ruby/struct:SomeJob\n  :systempassword: s3cr3t-value\n"
      sql = %(INSERT INTO "delayed_jobs" ("queue", "handler") ) +
            %(VALUES ('cc-generic', '#{handler}'))
      db.log_connection_yield(sql, nil) {}

      expect(logs.string).to include('[REDACTED]')
      expect(logs.string).not_to include('s3cr3t-value')
    end

    it 'redacts MySQL backtick-quoted delayed_jobs statements' do
      sql = %(INSERT INTO `delayed_jobs` (`queue`, `handler`) ) +
            %(VALUES ('cc-generic', '--- !ruby/object:Foo systempassword: s3cr3t-value'))
      db.log_connection_yield(sql, nil) {}

      expect(logs.string).to include('[REDACTED]')
      expect(logs.string).not_to include('s3cr3t-value')
    end

    it 'redacts MySQL backtick-quoted UPDATE handler column' do
      sql = %(UPDATE `delayed_jobs` SET `handler` = ) +
            %('--- !ruby/object:Foo systempassword: s3cr3t-value', `attempts` = 7)
      db.log_connection_yield(sql, nil) {}

      expect(logs.string).to include('[REDACTED]')
      expect(logs.string).not_to include('s3cr3t-value')
    end

    it 'redacts schema-qualified delayed_jobs statements' do
      sql = %(UPDATE "public"."delayed_jobs" SET "handler" = ) +
            %('--- !ruby/object:Foo systempassword: s3cr3t-value')
      db.log_connection_yield(sql, nil) {}

      expect(logs.string).to include('[REDACTED]')
      expect(logs.string).not_to include('s3cr3t-value')
    end

    it 'redacts the handler value on UPDATE (retry path) but keeps other columns' do
      sql = %(UPDATE "delayed_jobs" SET "handler" = ) +
            %('--- !ruby/object:Foo :systempassword: s3cr3t-value', "attempts" = 7 WHERE "id" = 71)
      db.log_connection_yield(sql, nil) {}

      expect(logs.string).to include('[REDACTED]')
      expect(logs.string).not_to include('s3cr3t-value')
      expect(logs.string).to include('"attempts" = 7')
    end

    it 'leaves last_error intact for debugging' do
      sql = %(UPDATE "delayed_jobs" SET "last_error" = 'RuntimeError: broker returned 500\nbacktrace line 1', ) +
            %("attempts" = 2 WHERE "id" = 71)
      db.log_connection_yield(sql, nil) {}

      expect(logs.string).to include('RuntimeError: broker returned 500')
      expect(logs.string).not_to include('[REDACTED]')
    end

    it 'leaves statements for other tables untouched' do
      sql = %(INSERT INTO "apps" ("name", "handler") VALUES ('my-app', 'not-a-secret'))
      db.log_connection_yield(sql, nil) {}

      expect(logs.string).to include('not-a-secret')
      expect(logs.string).not_to include('[REDACTED]')
    end

    it 'handles embedded doubled-quote escapes in the handler literal' do
      sql = %(INSERT INTO "delayed_jobs" ("handler") ) +
            %(VALUES ('--- !ruby/object:Foo note: it''s secret s3cr3t-value'))
      db.log_connection_yield(sql, nil) {}

      expect(logs.string).to include('[REDACTED]')
      expect(logs.string).not_to include('s3cr3t-value')
    end
  end
end
