require 'digest/xxhash'

module CloudFoundry
  module Middleware
    module UserResetInterval
      def next_expires_in(user_guid, reset_interval_in_minutes)
        interval = reset_interval_in_minutes.minutes.to_i
        offset = Digest::XXH64.hexdigest(user_guid).remainder(interval)

        interval - (Time.now.to_i - offset).remainder(interval)
      end
    end
  end
end
