module Sequel
  module Plugins
    module MicrosecondTimestampPrecision
      module DatasetMethods
        def default_timestamp_format
          "'%Y-%m-%d %H:%M:%S.%6N'"
        end
      end
    end
  end
end
