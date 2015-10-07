module VCAP::CloudController
  class CacheKeyPresenter
    def self.cache_key(guid:, stack_name:)
      "#{guid}/#{stack_name}"
    end
  end
end
