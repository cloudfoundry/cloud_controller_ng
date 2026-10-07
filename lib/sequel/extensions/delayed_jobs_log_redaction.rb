# frozen_string_literal: true

module Sequel::DelayedJobsLogRedaction
  # Redact the serialized job payload (handler) from any logged SQL that writes the
  # delayed_jobs table. The handler is the only value whose sole log path is the SQL
  # statement log and that carries user-submitted parameters; it has no debugging value
  # in a log line. The error columns (cf_api_error/last_error) are intentionally NOT
  # redacted here — they are needed for debugging and only reach the SQL log when
  # log_db_queries is enabled.
  REDACTED = "'[REDACTED]'"
  DELAYED_JOBS_TABLE = /(?:[`"]?\w+[`"]?\.)?[`"]?delayed_jobs[`"]?/i
  HANDLER_COLUMN = /[`"]?handler[`"]?/i

  def log_connection_yield(sql, conn, args=nil)
    if @loggers.any? && sql.downcase.include?('delayed_jobs')
      sql = redact_delayed_jobs(sql)
      # Sequel's base logger appends "; #{args.inspect}" to the logged line. If bound args
      # carry the serialized handler, redact there too.
      args = redact_args(args) if args && args.inspect.include?('!ruby')
    end
    super
  end

  private

  def redact_delayed_jobs(sql)
    return sql unless /\b(?:INSERT INTO|UPDATE)\s+#{DELAYED_JOBS_TABLE}/io.match?(sql)

    # UPDATE "handler" = '...'
    sql = sql.gsub(/(#{HANDLER_COLUMN}\s*=\s*)'(?:[^']|'')*'/io, "\\1#{REDACTED}")
    # INSERT: the handler is a Psych-serialized Ruby object graph, which always starts
    # with the '--- !ruby' document marker regardless of the inner tag.
    sql.gsub(/'--- !ruby(?:[^']|'')*'/i, REDACTED)
  end

  # Redact only the bound-args element(s) that carry the serialized handler, leaving
  # non-sensitive values (queue, guid, run_at, ...) intact.
  def redact_args(args)
    case args
    when Array
      args.map { |a| sensitive_arg?(a) ? '[REDACTED]' : a }
    when Hash
      args.transform_values { |v| sensitive_arg?(v) ? '[REDACTED]' : v }
    else
      sensitive_arg?(args) ? '[REDACTED]' : args
    end
  end

  def sensitive_arg?(value)
    value.is_a?(String) && value.include?('!ruby')
  end
end

Sequel::Database.register_extension(:delayed_jobs_log_redaction, Sequel::DelayedJobsLogRedaction)
