module CloudFoundry
  module Middleware
    module TooManyRequests
      def too_many_requests!(env, error_name, retry_after:, extra_headers: {})
        headers = {}
        headers['Retry-After'] = retry_after.to_s
        headers['Content-Type'] = 'text/plain; charset=utf-8'
        message = rate_limit_error(env, error_name).to_json
        headers['Content-Length'] = message.bytesize.to_s
        [429, extra_headers.to_hash.merge(headers), [message]]
      end

      private

      def rate_limit_error(env, error_name)
        api_error = CloudController::Errors::ApiError.new_from_details(error_name)
        version = env['PATH_INFO'][0..2]
        if version == '/v2'
          ErrorPresenter.new(api_error, Rails.env.test?, V2ErrorHasher.new(api_error)).to_hash
        elsif version == '/v3'
          ErrorPresenter.new(api_error, Rails.env.test?, V3ErrorHasher.new(api_error)).to_hash
        end
      end
    end
  end
end
