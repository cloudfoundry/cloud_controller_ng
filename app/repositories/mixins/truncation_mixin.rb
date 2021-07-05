module VCAP::CloudController
  module TruncationMixin
    TRUNCATED_SUFFIX = ' (truncated)'.freeze
    TRUNCATE_THRESHOLD = 10000

    def truncate(message)
      message.truncate(TRUNCATE_THRESHOLD, omission: TRUNCATED_SUFFIX)
    end
  end
end
