require 'addressable/uri'

module VCAP::CloudController
  class RouteDomainSplitter

  def self.split(url_string)
      uri = Addressable::URI.parse(url_string)
      intermediate_domain_names = CloudController::DomainDecorator.new(uri.host).intermediate_domains.map(&:name)
      {
        protocol: uri.scheme,
        potential_host: uri.host, # host.sub.some-domain.com
        potential_domains: intermediate_domain_names,
        port: uri.port,
        path: uri.path
      }
    end

  end
end
