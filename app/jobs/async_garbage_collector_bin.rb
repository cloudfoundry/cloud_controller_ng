require 'async'
require 'async/http/internet'
require 'concurrent'

module VCAP::CloudController
  module Jobs
    class AsyncGarbageCollectorBin < VCAP::CloudController::Jobs::CCJob
      # Global lazy thread pool
      def self.db_thread_pool(config)
        @db_thread_pool ||= Concurrent::FixedThreadPool.new(config.dig(:async_gc, :db_thread_pool_size) || 5)
      end

      def perform
        config = VCAP::CloudController::Config.config.config_hash rescue {}

        unless FeatureFlag.enabled?('async_domain_sweeps')
          # Fallback to legacy delayed_job worker if FeatureFlag is off
          # Assuming DomainCleanupJob is a standard job class in the codebase
          Delayed::Job.enqueue(DomainCleanupJob.new) if defined?(DomainCleanupJob)
          return
        end

        pool = self.class.db_thread_pool(config)
        max_concurrent = config.dig(:async_gc, :max_concurrent_deletes) || 5
        timeout_seconds = config.dig(:async_gc, :blob_delete_timeout_seconds) || 10

        Sync do |task|
          semaphore = Async::Semaphore.new(max_concurrent)
          internet = Async::HTTP::Internet.new
          
          # Fetch orphaned blobs list via DB thread pool
          future = Concurrent::Promises.future_on(pool) do
            # Mocking the actual Sequel query
            defined?(Blob) ? Blob.where(orphaned: true).all : []
          end
          
          # Wait non-blockingly using Notification
          notification = Async::Notification.new
          future.on_fulfillment { |result| notification.signal(result) }
          blobs = notification.wait

          # Optional: log and metric for jobs processed
          if defined?(Statsd) && Statsd.logger
            Statsd.logger.increment('async_gc.jobs.processed')
          end

          blobs.each do |blob|
            # Abort loop if feature flag toggled off mid-run
            unless FeatureFlag.enabled?('async_domain_sweeps')
              # Log warning
              logger = VCAP::CloudController::TelemetryLogger.v2_dispatcher rescue nil
              logger&.warn('async_domain_sweeps feature flag was disabled mid-flight. Aborting remainder of sweeps.')
              break
            end

            semaphore.async do
              begin
                task.with_timeout(timeout_seconds) do
                  # Compose the DELETE URL
                  delete_url = compose_blob_url(blob)
                  
                  # Use persistent HTTP client to send DELETE
                  response = internet.delete(delete_url)
                  
                  if response.success?
                    # On success, mark blob as deleted in DB using the same pattern
                    delete_future = Concurrent::Promises.future_on(pool) do
                      blob.delete if blob.respond_to?(:delete)
                    end
                    
                    delete_notification = Async::Notification.new
                    delete_future.on_fulfillment { |_res| delete_notification.signal }
                    delete_notification.wait
                    
                    if defined?(Statsd) && Statsd.logger
                      Statsd.logger.increment('async_gc.jobs.success')
                    end
                  else
                    if defined?(Statsd) && Statsd.logger
                      Statsd.logger.increment('async_gc.jobs.failure')
                    end
                  end
                  
                  response.close
                end
              rescue StandardError => e
                if defined?(Statsd) && Statsd.logger
                  Statsd.logger.increment('async_gc.jobs.failure')
                end
                # Log exception gracefully
              end
            end
          end

        ensure
          internet&.close if defined?(internet)
        end
      end

      private

      def compose_blob_url(blob)
        # Mock composed URL based on Blobstore config
        blob.respond_to?(:url) ? blob.url : "http://blobstore.internal/blobs/#{blob.id}"
      end
    end
  end
end
