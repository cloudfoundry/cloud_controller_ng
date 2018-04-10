require 'spec_helper'
require 'cloud_controller/app_manifest/route_domain_splitter'

module VCAP::CloudController
  RSpec.describe RouteDomainSplitter do
    context 'when there is a valid host and domain' do
      it 'splits a URL string into its route components' do
        url = 'http://host.sub.some-domain.com:9101/path'
        expect(RouteDomainSplitter.split(url)).to eq(
          protocol: 'http',
          potential_host: 'host.sub.some-domain.com',
          potential_domains: [
            'host.sub.some-domain.com',
            'sub.some-domain.com',
            'some-domain.com'
          ],
          port: 9101,
          path: '/path'
        )
      end
    end
  end
end
