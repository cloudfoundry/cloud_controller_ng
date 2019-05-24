module OPI
  class BaseClient
    def initialize(config)
      @config = config
      @client = HTTPClient.new(base_url: url)
    end

    private

    def url
      URI(config.get(:opi, :url))
    end

    attr_reader :client, :config
  end
end
