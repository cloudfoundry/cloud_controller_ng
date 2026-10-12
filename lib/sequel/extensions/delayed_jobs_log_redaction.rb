# frozen_string_literal: true

module Sequel::DelayedJobsLogRedaction
  # Redact the serialized job payload (handler) from any logged SQL that writes the
  # delayed_jobs table.
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

    sql = sql.gsub(/(#{HANDLER_COLUMN}\s*=\s*)'(?:[^']|'')*'/io, "\\1#{REDACTED}")
    # INSERT: the handler is a Psych-serialized Ruby object graph, which always starts
    # with the '--- !ruby' document marker regardless of the inner tag.
    sql.gsub(/'--- !ruby(?:[^']|'')*'/i, REDACTED)
  end

  def redact_args(args)
    return args unless args.is_a?(Array)

    args.map { |a| sensitive_arg?(a) ? '[REDACTED]' : a }
  end

  def sensitive_arg?(value)
    value.is_a?(String) && value.include?('!ruby')
  end
end

Sequel::Database.register_extension(:delayed_jobs_log_redaction, Sequel::DelayedJobsLogRedaction)
