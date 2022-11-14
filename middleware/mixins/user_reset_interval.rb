module CloudFoundry
  module Middleware
    module UserResetInterval
      def next_expires_in(user_guid, reset_interval_in_minutes)
        interval = reset_interval_in_minutes.minutes.to_i
        offset = OpenSSL::Digest::MD5.hexdigest(user_guid).hex.remainder(interval)

        interval - (Time.now.utc - offset).to_i.remainder(interval)
      end
    end
  end
end
