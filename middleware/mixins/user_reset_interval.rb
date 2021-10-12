module CloudFoundry
  module Middleware
    module UserResetInterval
      def next_reset_interval(user_guid, reset_interval_in_minutes)
        interval = reset_interval_in_minutes.minutes.to_i
        offset = Digest::MD5.hexdigest(user_guid).hex.remainder(interval)

        no_of_intervals = ((Time.now.utc - offset).to_f / interval).floor + 1

        Time.at(offset + (no_of_intervals * interval)).utc
      end
    end
  end
end
