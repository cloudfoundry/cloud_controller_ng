module VCAP::CloudController
  module Presenters
    module V3
      class CacheKeyPresenter
        def self.cache_key(guid:, stack_name:)
          "#{guid}/#{stack_name}"
        end
      end
    end
  end
end
