module VCAP::CloudController
  class ServiceBindingDeleteFetcher
    def initialize(guid)
      @guid = guid
    end

    def fetch
      ServiceBinding.where(guid: @guid)
    end
  end
end
