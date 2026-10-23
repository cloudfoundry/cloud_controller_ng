# frozen_string_literal: true

module Sequel::DelayedJobsLogRedaction
  # Redact the serialized job payload (handler) from any logged SQL that writes the
  # delayed_jobs table.
  REDACTED = "'[REDACTED]'"
  DELAYED_JOBS_TABLE = /(?:[`"]?\w+[`"]?\.)?[`"]?delayed_jobs[`"]?(?=\W|$)/i
  HANDLER_COLUMN = /\b[`"]?handler[`"]?/i

  def log_connection_yield(sql, conn, args=nil)
    if @loggers.any? && delayed_jobs_write_sql?(sql)
      # Compute redacted_indexes before mutating sql so the $N placeholders we scan for
      # are from the original SQL, not the already-redacted literal form.
      args = redact_args(sql, args) if args.is_a?(Array)
      sql = redact_delayed_jobs(sql)
    end
    super
  end

  private

  def delayed_jobs_write_sql?(sql)
    /\b(?:INSERT INTO|UPDATE)\s+#{DELAYED_JOBS_TABLE}/io.match?(sql)
  end

  def redact_delayed_jobs(sql)
    sql = sql.gsub(/(#{HANDLER_COLUMN}\s*=\s*)'(?:[^']|'')*'/io, "\\1#{REDACTED}")
    # INSERT only: the handler is a positional value with no column-name context.
    # Scoped to INSERT to avoid redacting last_error/cf_api_error on UPDATE statements,
    # which may contain '--- !ruby' if a job failed while processing YAML input.
    sql = sql.gsub(/'\s*--- !ruby(?:[^']|'')*'/i, REDACTED) if /\bINSERT\b/i.match?(sql)
    sql
  end

  def redact_args(sql, args)
    return args unless args.is_a?(Array)

    redacted_indexes = redacted_indexes(sql)
    return args if redacted_indexes.empty?

    args.each_with_index.map { |a, index| redacted_indexes.include?(index) ? '[REDACTED]' : a }
  end

  def redacted_indexes(sql)
    indexes = []

    if (columns = sql[/\bINSERT INTO\s+#{DELAYED_JOBS_TABLE}\s*\((.*?)\)\s*VALUES/i, 1]) &&
       (values = sql[/\bVALUES\s*\((.*?)\)/i, 1])
      handler_index = columns.split(',').map(&:strip).index { |column| HANDLER_COLUMN.match?(column) }
      # Sequel emits all-$N placeholders for bound INSERTs, so VALUES(...) contains no literal commas.
      # Scan $N tokens explicitly rather than splitting on commas so a future literal value with a comma
      # cannot shift the index arithmetic.
      value_placeholders = values.scan(/\$(\d+)/).map { |m| m[0].to_i }
      if handler_index && (n = value_placeholders[handler_index])
        indexes << (n - 1)
      end
    end

    # For UPDATE: scan each "column = $N" assignment directly in the SQL rather than
    # extracting the SET clause (a lazy match would stop early if a value contains WHERE).
    sql.scan(/#{HANDLER_COLUMN}\s*=\s*\$(\d+)/i) do |match|
      indexes << (match[0].to_i - 1)
    end

    indexes.uniq
  end
end

Sequel::Database.register_extension(:delayed_jobs_log_redaction, Sequel::DelayedJobsLogRedaction)
