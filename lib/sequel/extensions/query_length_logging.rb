# frozen-string-literal: true

module Sequel::QueryLengthLogging
  # Include SQL query length when logging query.
  def log_connection_yield(sql, conn, args=nil)
    unless @loggers.empty?
      sql = "(query_length=#{sql.length}) #{sql}"
    end
    super
  end
end

Sequel::Database.register_extension(:query_length_logging, Sequel::QueryLengthLogging)
