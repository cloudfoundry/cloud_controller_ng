module Sequel
  module Plugins
    module MicrosecondTimestampPrecision
      module DatasetMethods
        def supports_timestamp_usecs?
          true
        end
      end
    end
  end
end
