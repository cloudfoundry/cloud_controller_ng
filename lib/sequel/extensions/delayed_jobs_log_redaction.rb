# frozen_string_literal: true

module Sequel::DelayedJobsLogRedaction
  # Redact column values from any logged SQL that writes the delayed_jobs table.
  REDACTED = "'[REDACTED]'"
  DELAYED_JOBS_TABLE = /(?:[`"]?\w+[`"]?\.)?[`"]?delayed_jobs[`"]?/i
  # Columns that can carry user/broker content: the serialized job payload (handler) and
  # the error columns (a broker/API error can echo submitted parameters).
  SENSITIVE_COLUMNS = /[`"]?(?:handler|cf_api_error|last_error)[`"]?/i

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

    # UPDATE "col" = '...' for any sensitive column.
    sql = sql.gsub(/(#{SENSITIVE_COLUMNS}\s*=\s*)'(?:[^']|'')*'/io, "\\1#{REDACTED}")
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
