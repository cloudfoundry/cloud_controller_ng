# frozen_string_literal: true

module Sequel::DelayedJobsLogRedaction
  # Redact the `handler` column value from any logged SQL that writes the delayed_jobs table.
  REDACTED = "'[REDACTED]'"

  def log_connection_yield(sql, conn, args=nil)
    sql = redact_delayed_jobs(sql) if @loggers.any? && sql.include?('delayed_jobs')
    super
  end

  private

  def redact_delayed_jobs(sql)
    return sql unless /\b(?:INSERT INTO|UPDATE)\s+"?delayed_jobs"?/i.match?(sql)

    sql = sql.gsub(/("?handler"?\s*=\s*)'(?:[^']|'')*'/i, "\\1#{REDACTED}")

    sql.gsub(%r{'--- !ruby/object:(?:[^']|'')*'}, REDACTED)
  end
end

Sequel::Database.register_extension(:delayed_jobs_log_redaction, Sequel::DelayedJobsLogRedaction)
