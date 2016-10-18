module CloudFoundry
  module Middleware
    class RateLimiter
      REQUEST_EXCEEDED_MESSAGE_BODY = 'Rate Limit Exceeded'.freeze
      def initialize(app, general_limit, interval)
        @app           = app
        @general_limit = general_limit
        @interval      = interval
      end

      def call(env)
        rate_limit_headers = {}

        if env['cf.user_guid']
          request_count = VCAP::CloudController::RequestCount.find_or_create(user_guid: env['cf.user_guid']) do |created_request_count|
            created_request_count.valid_until = Time.now + @interval.minutes
          end

          request_count.db.transaction do
            request_count.lock!

            reset_request_count(request_count) if reset_interval_expired(request_count)
            request_count.count += 1
            request_count.save
          end

          rate_limit_headers['X-RateLimit-Limit']     = @general_limit.to_s
          rate_limit_headers['X-RateLimit-Reset']     = request_count.valid_until.utc.to_i.to_s
          rate_limit_headers['X-RateLimit-Remaining'] = [0, @general_limit - request_count.count].max.to_s

          if exceeded_rate_limit(request_count) && not_admin
            rate_limit_headers['Retry-After'] = rate_limit_headers['X-RateLimit-Reset']
            rate_limit_headers['Content-Type'] = 'text/plain; charset=utf-8'
            rate_limit_headers['Content-Length'] = REQUEST_EXCEEDED_MESSAGE_BODY.length.to_s
            return [429, rate_limit_headers, [REQUEST_EXCEEDED_MESSAGE_BODY]]
          end
        end

        status, headers, body = @app.call(env)
        [status, headers.merge(rate_limit_headers), body]
      end

      def exceeded_rate_limit(request_count)
        request_count.count > @general_limit
      end

      def reset_interval_expired(request_count)
        request_count.valid_until < Time.now
      end

      def reset_request_count(request_count)
        request_count.valid_until = Time.now + @interval.minutes
        request_count.count       = 0
      end

      def not_admin
        !VCAP::CloudController::SecurityContext.admin? && !VCAP::CloudController::SecurityContext.admin_read_only?
      end
    end
  end
end
