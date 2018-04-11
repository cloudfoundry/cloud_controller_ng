require 'addressable/uri'

module VCAP::CloudController
  class RouteDomainSplitter
    def self.split(url_string)
      uri = Addressable::URI.parse(url_string)
      route = uri.host
      potential_host = uri.host

      if route.split('.').first == '*'
        # fail somehow if there is a port
        potential_host = '*'
        potential_domains = [route.split('.')[1..-1].join('.')]
      else
        potential_domains = CloudController::DomainDecorator.new(route).intermediate_domains.
                            map(&:name).sort_by(&:length).reverse
      end

      {
        protocol: uri.scheme,
        potential_host: potential_host,
        potential_domains: potential_domains,
        port: uri.port,
        path: uri.path
      }
    end
  end
end
