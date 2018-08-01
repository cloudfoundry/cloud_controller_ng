require 'spec_helper'
require 'cloud_controller/blobstore/fog/cdn'
require 'cloudfront-signer'

module CloudController
  module Blobstore
    RSpec.describe Cdn do
      let(:cdn_host) { 'https://some_distribution.cloudfront.net' }
      let(:cdn) { Cdn.make(cdn_host) }

      describe '.make' do
        it 'returns nil for an empty host' do
          expect(Cdn.make(nil)).to be_nil
          expect(Cdn.make('')).to be_nil
        end

        it 'returns a real Cdn for a non-empty host' do
          expect(Cdn.make('example.com')).to be_a(Cdn)
        end
      end

      describe '.new' do
        it 'is private' do
          expect {
            Cdn.new('foo')
          }.to raise_error(/private method/)
        end
      end

      describe '#get' do
        let(:path_location) { 'ab/cd/abcdefghi' }

        context 'on http errors' do
          let(:fake_client) { instance_double(HTTPClient, ssl_config: double(set_default_paths: true)) }

          before do
            allow(HTTPClient).to receive(:new).and_return(fake_client)
          end

          it 'tries 3 times' do
            allow(fake_client).to receive(:get).and_raise('nope')
            expect {
              cdn.get(path_location)
            }.to raise_error('nope')
            expect(fake_client).to have_received(:get).exactly(3).times
          end
        end

        context 'when CloudFront Signer is not configured' do
          before do
            allow(Aws::CF::Signer).to receive(:is_configured?).and_return(false)
            @stub = stub_request(:get, "#{cdn_host}/#{path_location}").to_return(body: 'barbaz')
          end

          it 'yields' do
            expect { |yielded|
              cdn.get(path_location, &yielded)
            }.to yield_control
          end

          it 'downloads the file' do
            cdn.get(path_location) do |chunk|
              expect(chunk).to eq('barbaz')
            end
          end

          it 'requests the correct url' do
            cdn.get(path_location) {}
            expect(@stub).to have_been_requested
          end
        end

        context 'when CloudFront Signer is configured' do
          before { allow(Aws::CF::Signer).to receive(:is_configured?).and_return(true) }

          it 'returns a signed URI using the CDN' do
            expect(Aws::CF::Signer).to receive(:sign_url).with("#{cdn_host}/#{path_location}").and_return('http://signed_url')
            stub = stub_request(:get, 'signed_url').to_return(body: 'foobar')

            cdn.get(path_location) {}

            expect(stub).to have_been_requested
          end
        end
      end
    end
  end
end
