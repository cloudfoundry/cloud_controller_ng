require 'spec_helper'

module VCAP::CloudController
  RSpec.describe 'Shared UAA issuer discovery' do
    let(:locator) { CloudController::DependencyLocator.instance }
    let(:discovery_url) { 'https://uaa.service.cf.internal/.well-known/openid-configuration' }

    it 'reuses successful discovery across callers until the cache expires' do
      request = stub_request(:get, discovery_url).to_return(body: { issuer: 'https://uaa.example.test/oauth/token' }.to_json)

      Timecop.freeze do
        first = locator.uaa_issuer_discovery
        expect(first.issuer).to eq('https://uaa.example.test/oauth/token')
        expect(locator.uaa_issuer_discovery.issuer).to eq('https://uaa.example.test/oauth/token')
        expect(request).to have_been_requested.once
        Timecop.travel(Time.now + 301)
        expect(first.issuer).to eq('https://uaa.example.test/oauth/token')
        expect(request).to have_been_requested.twice
      end
    end

    it 'does not cache unsuccessful discovery and permits retry' do
      request = stub_request(:get, discovery_url).to_return(status: 503).then.to_return(body: { issuer: 'https://uaa.example.test/oauth/token' }.to_json)

      expect { locator.uaa_issuer_discovery.issuer }.to raise_error(/issuer/)
      expect(locator.uaa_issuer_discovery.issuer).to eq('https://uaa.example.test/oauth/token')
      expect(request).to have_been_requested.twice
    end

    it 'shares one successful lookup among concurrent callers' do
      request = stub_request(:get, discovery_url).to_return(body: { issuer: 'https://uaa.example.test/oauth/token' }.to_json)
      discovery = locator.uaa_issuer_discovery
      gate = Queue.new
      threads = Array.new(4) do
        Thread.new do
          gate.pop
          discovery.issuer
        end
      end
      threads.size.times { gate << true }

      expect(threads.map(&:value)).to eq(Array.new(4, 'https://uaa.example.test/oauth/token'))
      expect(request).to have_been_requested.once
    end

    it 'treats Ruby object markers as ordinary JSON data' do
      stub_request(:get, discovery_url).to_return(body: '{"^o":"Object","issuer":"https://uaa.example.test/oauth/token"}')

      expect(locator.uaa_issuer_discovery.issuer).to eq('https://uaa.example.test/oauth/token')
    end

    it 'fails closed instead of using an expired issuer when refresh fails' do
      stub_request(:get, discovery_url).to_return(body: { issuer: 'https://uaa.example.test/oauth/token' }.to_json).then.to_return(status: 503)

      Timecop.freeze do
        expect(locator.uaa_issuer_discovery.issuer).to eq('https://uaa.example.test/oauth/token')
        Timecop.travel(Time.now + 301)
        expect { locator.uaa_issuer_discovery.issuer }.to raise_error(/issuer/)
      end
    end
  end
end
