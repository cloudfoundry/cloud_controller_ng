require 'spec_helper'
require 'cloud_controller/app_manifest/manifest_route'

module VCAP::CloudController
  RSpec.describe ManifestRoute do
    describe 'validating routes' do
      describe 'valid route' do
        context 'when the route has a path' do
          let(:route) { 'path.example.com/path' }

          it 'is valid' do
            manifest_route = ManifestRoute.parse(route)
            expect(manifest_route.valid?).to eq(true)
          end
        end

        context 'when the route specifies http protocol' do
          let(:route) { 'http://example.com' }

          it 'is valid' do
            manifest_route = ManifestRoute.parse(route)
            expect(manifest_route.valid?).to eq(true)
          end
        end

        context 'when the route specifies https protocol' do
          let(:route) { 'https://example.com' }

          it 'is valid' do
            manifest_route = ManifestRoute.parse(route)
            expect(manifest_route.valid?).to eq(true)
          end
        end

        context 'when the route uses a wildcard' do
          let(:route) { '*.example.com' }

          it 'is valid' do
            manifest_route = ManifestRoute.parse(route)
            expect(manifest_route.valid?).to eq(true)
          end
        end

        context 'when the route specifies tcp protocol and a port' do
          let(:route) { 'tcp://example.com:1234' }

          it 'is valid' do
            manifest_route = ManifestRoute.parse(route)
            expect(manifest_route.valid?).to eq(true)
          end
        end

        context 'when there is a port and no protocol, which implies a tcp route' do
          let(:route) { 'tcp-example.com:1234' }

          it 'is valid' do
            manifest_route = ManifestRoute.parse(route)
            expect(manifest_route.valid?).to eq(true)
          end
        end
      end

      describe 'invalid routes' do
        context 'when a route specifies a protocol other than http/s' do
          let(:route) { 'ftp://www.example.com' }

          it 'is invalid' do
            manifest_route = ManifestRoute.parse(route)
            expect(manifest_route.valid?).to eq(false)
          end
        end

        context 'when a route has fewer than two segments' do
          let(:route) { 'example' }

          it 'is invalid' do
            manifest_route = ManifestRoute.parse(route)
            expect(manifest_route.valid?).to eq(false)
          end
        end

        context 'when a route only specifies a path' do
          let(:route) { '/example' }

          it 'is invalid' do
            manifest_route = ManifestRoute.parse(route)
            expect(manifest_route.valid?).to eq(false)
          end
        end

        context 'when a route specifies a port and non-tcp protocol' do
          let(:route) { 'http://www.example.com:8080' }

          it 'is invalid' do
            manifest_route = ManifestRoute.parse(route)
            expect(manifest_route.valid?).to eq(false)
          end
        end

        context 'when there is a nil route' do
          let(:route) { nil }

          it 'is invalid' do
            manifest_route = ManifestRoute.parse(route)

            expect(manifest_route.valid?).to eq(false)
          end
        end
      end
    end

    describe 'parsing routes' do
      it 'returns a hash of the route components' do
        route = ManifestRoute.parse('http://host.sub.some-domain.com/path')

        expect(route.to_hash).to eq({
          candidate_host_domain_pairs: [
            { host: '', domain: 'host.sub.some-domain.com' },
            { host: 'host', domain: 'sub.some-domain.com' },
          ],
          port: nil,
          path: '/path'
        })
      end

      it 'parses a wildcard url into route components' do
        route = ManifestRoute.parse('http://*.sub.some-domain.com/path')

        expect(route.to_hash).to eq({
          candidate_host_domain_pairs: [
            { host: '*', domain: 'sub.some-domain.com' },
          ],
          port: nil,
          path: '/path'
        })
      end

      it 'parses a url without protocol into route components' do
        route = ManifestRoute.parse('potato.sub.some-domain.com/path')

        expect(route.to_hash).to eq({
          candidate_host_domain_pairs: [
            { host: '', domain: 'potato.sub.some-domain.com' },
            { host: 'potato', domain: 'sub.some-domain.com' },
          ],
          port: nil,
          path: '/path'
        })
      end

      it 'parses a tcp route with port into route components' do
        route = ManifestRoute.parse('potato.sub.some-domain.com:1234')

        expect(route.to_hash).to eq({
          candidate_host_domain_pairs: [
            { host: '', domain: 'potato.sub.some-domain.com' },
            { host: 'potato', domain: 'sub.some-domain.com' },
          ],
          port: 1234,
          path: '',
        })
      end
    end

    describe '#to_s' do
      it 'returns the full route' do
        route = ManifestRoute.parse('path.example.com/path')
        expect(route.to_s).to eq('path.example.com/path')
      end
    end
  end
end
