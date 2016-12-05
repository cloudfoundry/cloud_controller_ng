require 'spec_helper'

module VCAP::CloudController
  module Diego
    module Docker
      RSpec.describe DesiredLrpBuilder do
        subject(:builder) { described_class.new(config, app_request) }
        let(:app_request) do
          {
            'docker_image' => 'user/repo:tag'
          }
        end
        let(:config) do
          {
            diego: {
              lifecycle_bundles: {
                docker: 'http://docker.example.com/path/to/lifecycle.tgz'
              }
            }
          }
        end

        describe '#root_fs' do
          it 'uses the DockerURIConverter' do
            converter = instance_double(DockerURIConverter, convert: 'foobar')
            allow(DockerURIConverter).to receive(:new).and_return(converter)

            expect(builder.root_fs).to eq('foobar')
            expect(converter).to have_received(:convert).with('user/repo:tag')
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
                cache_key: 'docker-lifecycle',
              )
            ])
            expect(LifecycleBundleUriGenerator).to have_received(:uri).with('http://docker.example.com/path/to/lifecycle.tgz')
          end
        end

        describe '#setup' do
          it 'returns nil' do
            expect(builder.setup).to be_nil
          end
        end

        describe '#global_environment_variables' do
          it 'returns an empty list' do
            expect(builder.global_environment_variables).to be_empty
          end
        end
      end
    end
  end
end
