module CloudFoundry
  module Middleware
    module UserResetInterval
      def next_expires_in(user_guid, reset_interval_in_minutes)
        interval = reset_interval_in_minutes.minutes.to_i
        offset = OpenSSL::Digest::MD5.hexdigest(user_guid).hex.remainder(interval)
        # TODO: replace hash function with faster (e.g. https://github.com/nashby/xxhash) and FIPS compliant algorithm.

        interval - (Time.now.to_i - offset).remainder(interval)
      end
    end
  end
end
