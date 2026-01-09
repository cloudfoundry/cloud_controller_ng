# frozen_string_literal: true

#
# The connection_metrics extension enhances a database's
# connection pool to store metrics about the use of connections.
# Whenever a connection is acquired or released the number of
# currently acquired connections is emitted. Same for making new
# connections and disconnecting them from the DB. Example of use:
#
#   DB.extension(:connection_metrics)
#
# Note that this extension has been only tested with a
# connection pool type :threaded. To use it with other
# connection pool types it might need adjustments.
#
# Related module: Sequel::ConnectionMetrics

module Sequel
  module ConnectionMetrics
    # Initialize the data structures used by this extension.
    def self.extended(pool)
      raise Error.new('cannot load connection_metrics extension if using a connection pool type different than :threaded') unless pool.pool_type == :threaded

      pool.instance_exec do
        sync do
          @prometheus_updater = CloudController::DependencyLocator.instance.prometheus_updater
          @connection_info = {}
        end
      end
    end

    private

    def acquire(thread)
      begin
        if (conn = super)
          acquired_at = Time.now.utc
          @prometheus_updater.increment_gauge_metric(:cc_acquired_db_connections_total, labels: { process_type: })
          @connection_info[thread] ||= {}
          @connection_info[thread][:acquired_at] = acquired_at
        end
      rescue Sequel::PoolTimeout
        @prometheus_updater.increment_gauge_metric(:cc_db_connection_pool_timeouts_total, labels: { process_type: })
        raise
      ensure
        # acquire calls assign_connection, where the thread possibly has to wait for a free connection.
        # For both cases, when the thread acquires a connection in time, or when it runs into a PoolTimeout,
        # we emmit the time the thread waited for a connection.
        if @connection_info[thread] && @connection_info[thread].key?(:waiting_since)
          @prometheus_updater.update_histogram_metric(:cc_db_connection_wait_duration_seconds, (Time.now.utc - @connection_info[thread][:waiting_since]).seconds,
                                                      labels: { process_type: })
          @connection_info[thread].delete(:waiting_since)
        end
      end
      conn
    end

    def assign_connection(thread)
      # if assign_connection does not return a connection, the pool is exhausted and the thread has to wait
      unless (conn = super)
        waiting_since = Time.now.utc
        @connection_info[thread] = { waiting_since: } unless @connection_info[thread] && @connection_info[thread].key?(:waiting_since)
      end
      conn
    end

    def make_new(server)
      conn = super
      @prometheus_updater.update_gauge_metric(:cc_open_db_connections_total, size, labels: { process_type: })
      conn
    end

    def disconnect_connection(conn)
      super
      @prometheus_updater.update_gauge_metric(:cc_open_db_connections_total, size, labels: { process_type: })
    end

    def release(thread)
      super

      # acquired_at should be always set, but as a safeguard we check that it is present before accessing
      if @connection_info[thread] && @connection_info[thread].key?(:acquired_at)
        @prometheus_updater.update_histogram_metric(:cc_db_connection_hold_duration_seconds, (Time.now.utc - @connection_info[thread][:acquired_at]).seconds,
                                                    labels: { process_type: })
      end

      @prometheus_updater.decrement_gauge_metric(:cc_acquired_db_connections_total, labels: { process_type: })
      @connection_info.delete(thread)
    end

    def process_type
      ENV.fetch('PROCESS_TYPE', nil)
    end
  end

  Database.register_extension(:connection_metrics) { |db| db.pool.extend(ConnectionMetrics) }
end
