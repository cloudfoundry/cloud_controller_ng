# frozen_string_literal: true

module Sequel::DelayedJobsLogRedaction
  # Redact the `handler` column value from any logged SQL that writes the delayed_jobs table.
  REDACTED = "'[REDACTED]'"

  def log_connection_yield(sql, conn, args=nil)
    if @loggers.any? && sql.include?('delayed_jobs')
      sql = redact_delayed_jobs(sql)
      # Sequel's base logger appends "; #{args.inspect}" to the logged line. If bound args
      # carry the serialized handler, redact there too.
      args = redact_args(args) if args && args.inspect.include?('!ruby/object:')
    end
    super
  end

  private

  def redact_delayed_jobs(sql)
    return sql unless /\b(?:INSERT INTO|UPDATE)\s+"?delayed_jobs"?/i.match?(sql)

    sql = sql.gsub(/("?handler"?\s*=\s*)'(?:[^']|'')*'/i, "\\1#{REDACTED}")

    sql.gsub(%r{'--- !ruby/object:(?:[^']|'')*'}, REDACTED)
  end

  # Replace a bound-args value whose inspected form contains a serialized handler.
  # Returns a plain string so the base logger's args.inspect cannot expose the payload.
  def redact_args(_args)
    '[REDACTED]'
  end
end

Sequel::Database.register_extension(:delayed_jobs_log_redaction, Sequel::DelayedJobsLogRedaction)
