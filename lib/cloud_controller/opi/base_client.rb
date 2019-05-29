module OPI
  class BaseClient
    def initialize(config)
      @config = config
      @client = HTTPClient.new(base_url: url)
      opi_config = config.get(:opi)
      client_cert_file = opi_config[:client_cert_file]
      client_key_file = opi_config[:client_key_file]
      ca_file = opi_config[:ca_file]
      if client_cert_file && client_key_file && ca_file
        client.ssl_config.add_trust_ca(ca_file)
        client.ssl_config.set_client_cert_file(client_cert_file, client_key_file)
      end
    end

    private

    def url
      URI(config.get(:opi, :url))
    end

    attr_reader :client, :config
  end
end
