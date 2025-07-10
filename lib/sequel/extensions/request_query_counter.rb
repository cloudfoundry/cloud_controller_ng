module Sequel
  module RequestQueryCounter
    def log_connection_yield(sql, conn, args=nil)
      VCAP::Request.increment_db_query_count
      super
    end
  end

  Database.register_extension(:request_query_counter) { |db| db.extend(RequestQueryCounter) }
end
