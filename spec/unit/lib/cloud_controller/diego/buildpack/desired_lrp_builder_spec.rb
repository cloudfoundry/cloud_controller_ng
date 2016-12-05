require 'spec_helper'

module VCAP::CloudController
  module Diego
    module Buildpack
      RSpec.describe DesiredLrpBuilder do
        subject(:builder) { described_class.new(config, app_request) }
        let(:app_request) do
          {
            'stack' => 'potato-stack'
          }
        end
        let(:config) do
          {
            diego: {
              file_server_url: 'http://file-server.example.com',
              lifecycle_bundles: {
                'buildpack/potato-stack': '/path/to/lifecycle.tgz',
              }
            }
          }
        end

        describe '#root_fs' do
          it 'returns a constructed root_fs' do
            expect(builder.root_fs).to eq('preloaded:potato-stack')
          end
        end

        describe '#cached_dependencies' do
          before do
            allow(LifecycleBundleUriGenerator).to receive(:uri).and_return('foo://bar.baz')
          end

          it 'returns an array of CachedDependency objects' do
            expect(builder.cached_dependencies).to eq([
              ::Diego::Bbs::Models::CachedDependency.new(
                from: 'foo://bar.baz',
                to: '/tmp/lifecycle',
                cache_key: 'buildpack-potato-stack-lifecycle',
              )
            ])
            expect(LifecycleBundleUriGenerator).to have_received(:uri).with('/path/to/lifecycle.tgz')
          end
        end
      end
    end
  end
end
