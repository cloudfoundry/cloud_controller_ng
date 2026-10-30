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

    it 'leaves last_error and cf_api_error intact (needed for debugging)' do
      sql = %(UPDATE "delayed_jobs" SET "last_error" = 'RuntimeError: broker returned 500\nbacktrace line 1', ) +
            %("cf_api_error" = 'provision failed', "attempts" = 2 WHERE "id" = 71)
      db.log_connection_yield(sql, nil) {}

      expect(logs.string).to include('RuntimeError: broker returned 500')
      expect(logs.string).to include('provision failed')
      expect(logs.string).not_to include('[REDACTED]')
    end

    it 'leaves last_error intact even when it contains !ruby content (e.g. job failed processing YAML input)' do
      sql = %(UPDATE "delayed_jobs" SET "last_error" = '--- !ruby/object:Foo pw: s3cr3t', "attempts" = 2 WHERE "id" = 71)
      db.log_connection_yield(sql, nil) {}

      expect(logs.string).to include('s3cr3t')
      expect(logs.string).not_to include('[REDACTED]')
    end

    it 'leaves last_error bound args intact even when they contain !ruby content' do
      sql = 'UPDATE "delayed_jobs" SET "last_error" = $1 WHERE "id" = 71'

      db.log_connection_yield(sql, nil, ['--- !ruby/object:Foo pw: s3cr3t']) {}

      expect(logs.string).to include('s3cr3t')
      expect(logs.string).not_to include('[REDACTED]')
    end

    it 'redacts only the handler bound arg when UPDATE includes other !ruby-like args' do
      sql = 'UPDATE "delayed_jobs" SET "handler" = $1, "last_error" = $2 WHERE "id" = 71'

      db.log_connection_yield(sql, nil, ['--- !ruby/object:Foo pw: s3cr3t', '--- !ruby/object:Bar debug detail']) {}

      expect(logs.string).to include('[REDACTED]')
      expect(logs.string).to include('debug detail')
      expect(logs.string).not_to include('s3cr3t')
    end

    it 'redacts handler bound arg even when a value contains the word WHERE' do
      # last_error may contain SQL snippets with WHERE; a lazy SET-clause regex would stop too early
      sql = 'UPDATE "delayed_jobs" SET "handler" = $1, "last_error" = $2 WHERE "id" = 71'

      db.log_connection_yield(sql, nil, ['--- !ruby/object:Foo pw: s3cr3t', 'query failed WHERE x = 1']) {}

      expect(logs.string).to include('[REDACTED]')
      expect(logs.string).to include('WHERE x = 1')
      expect(logs.string).not_to include('s3cr3t')
    end

    it 'does not redact column names that end in handler (e.g. request_handler)' do
      sql = %(UPDATE "delayed_jobs" SET "request_handler" = 'some-value', "attempts" = 1 WHERE "id" = 5)
      db.log_connection_yield(sql, nil) {}

      expect(logs.string).to include('some-value')
      expect(logs.string).not_to include('[REDACTED]')
    end

    it 'leaves statements for other tables untouched' do
      sql = %(INSERT INTO "apps" ("name", "handler") VALUES ('my-app', 'not-a-secret'))
      db.log_connection_yield(sql, nil) {}

      expect(logs.string).to include('not-a-secret')
      expect(logs.string).not_to include('[REDACTED]')
    end

    it 'does not redact tables whose names start with delayed_jobs (e.g. delayed_jobs_v2, delayed_jobs_staging)' do
      handler = '--- !ruby/object:Foo systempassword: s3cr3t-value'
      %w[delayed_jobs_v2 delayed_jobs_staging].each do |table|
        sql = %(INSERT INTO "#{table}" ("handler") VALUES ('#{handler}'))
        db.log_connection_yield(sql, nil) {}
      end

      expect(logs.string).not_to include('[REDACTED]')
    end

    it 'does not redact bound args for tables whose names start with delayed_jobs' do
      sql = 'INSERT INTO "delayed_jobs_v2" ("handler") VALUES ($1)'

      db.log_connection_yield(sql, nil, ['--- !ruby/object:Foo systempassword: s3cr3t-value']) {}

      expect(logs.string).to include('s3cr3t-value')
      expect(logs.string).not_to include('[REDACTED]')
    end

    it 'handles embedded doubled-quote escapes in the handler literal' do
      sql = %(INSERT INTO "delayed_jobs" ("handler") ) +
            %(VALUES ('--- !ruby/object:Foo note: it''s secret s3cr3t-value'))
      db.log_connection_yield(sql, nil) {}

      expect(logs.string).to include('[REDACTED]')
      expect(logs.string).not_to include('s3cr3t-value')
    end

    it 'redacts handler literals even when they have leading whitespace before the YAML tag' do
      sql = %(INSERT INTO "delayed_jobs" ("handler") VALUES (' --- !ruby/object:Foo pw: s3cr3t-value'))
      db.log_connection_yield(sql, nil) {}

      expect(logs.string).to include('[REDACTED]')
      expect(logs.string).not_to include('s3cr3t-value')
    end

    # The base Sequel logger appends "; #{args.inspect}" when a statement is logged with
    # bound args (prepared statements). Redact there too, for any !ruby tag.
    ['!ruby/object:', '!ruby/struct:', '!ruby/hash:'].each do |tag|
      it "redacts a serialized handler passed via bound args (#{tag})" do
        sql = 'INSERT INTO "delayed_jobs" ("handler") VALUES ($1)'
        db.log_connection_yield(sql, nil, ["--- #{tag}Foo systempassword: s3cr3t-value"]) {}

        expect(logs.string).to include('[REDACTED]')
        expect(logs.string).not_to include('s3cr3t-value')
      end
    end

    it 'redacts only the handler element of bound args, keeping other values' do
      sql = 'INSERT INTO "delayed_jobs" ("queue","guid","handler","run_at") VALUES ($1,$2,$3,$4)'
      args = ['cc-generic', 'guid-123', '--- !ruby/object:Foo systempassword: s3cr3t-value', '2026-10-07 11:00:00']
      db.log_connection_yield(sql, nil, args) {}

      expect(logs.string).not_to include('s3cr3t-value')
      expect(logs.string).to include('cc-generic')
      expect(logs.string).to include('guid-123')
      expect(logs.string).to include('2026-10-07 11:00:00')
    end
  end
end
