class Cdn
  def self.make(host)
    return nil if host.nil? || host == ""
    new(host)
  end

  attr_reader :host

  def initialize(host)
    @host = host
  end

  def get(path, &block)
    url = "#{host}/#{path}"
    url = AWS::CF::Signer.sign_url(url) if AWS::CF::Signer.is_configured?
    HTTPClient.new.get(url) do |chunk|
      block.yield chunk
    end
  end

  # Don't call new directly because there's logic in .make
  private_class_method(:new)
end