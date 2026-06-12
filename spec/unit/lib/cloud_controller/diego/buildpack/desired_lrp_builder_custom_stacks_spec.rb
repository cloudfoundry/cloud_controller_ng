require 'spec_helper'
require 'cloud_controller/diego/buildpack/desired_lrp_builder'
require 'cloud_controller/diego/custom_stack_uri_converter'

module VCAP::CloudController
  module Diego
    module Buildpack
      RSpec.describe DesiredLrpBuilder do
        let(:stack) { 'cflinuxfs4' }
        let(:config) do
          Config.new({
            diego: {
              use_privileged_containers_for_running: false,
              lifecycle_bundles: { "buildpack/#{stack}": 'http://lifecycle.example.com/bundle.tgz' },
              droplet_destinations: { stack.to_sym => '/home/vcap' },
              enable_declarative_asset_downloads: false
            }
          })
        end
        let(:opts) do
          {
            stack: stack,
            droplet_uri: 'http://droplet.example.com/droplet.tgz',
            process_guid: 'process-guid-1',
            droplet_hash: 'droplet-hash',
            ports: [8080],
            checksum_algorithm: 'sha256',
            checksum_value: 'checksum-value',
            start_command: './start',
            action_user: 'vcap',
            additional_container_env_vars: []
          }
        end

        subject(:builder) { DesiredLrpBuilder.new(config, opts) }

        before do
          VCAP::CloudController::Stack.find(name: 'cflinuxfs4') || VCAP::CloudController::Stack.create(name: 'cflinuxfs4')
        end

        describe '#root_fs' do
          context 'with a system stack' do
            it 'returns preloaded rootfs' do
              expect(builder.root_fs).to eq('preloaded:cflinuxfs4')
            end
          end

          context 'with a custom stack (docker:// URI)' do
            let(:stack) { 'docker://docker.io/cloudfoundry/cflinuxfs4:1.268.0' }
            let(:config) do
              Config.new({
                diego: {
                  use_privileged_containers_for_running: false,
                  lifecycle_bundles: { "buildpack/#{VCAP::CloudController::Stack.default.name}": 'http://lifecycle.example.com/bundle.tgz' },
                  droplet_destinations: { 'default-stack-name': '/home/vcap' },
                  enable_declarative_asset_downloads: false
                }
              })
            end

            it 'returns a docker:// rootfs URI in Diego format' do
              expect(builder.root_fs).to eq('docker://docker.io/cloudfoundry/cflinuxfs4#1.268.0')
            end
          end

          context 'with a custom stack from a private registry' do
            let(:stack) { 'docker://registry.example.com/my-org/my-stack:v2.0' }
            let(:config) do
              Config.new({
                diego: {
                  use_privileged_containers_for_running: false,
                  lifecycle_bundles: { "buildpack/#{VCAP::CloudController::Stack.default.name}": 'http://lifecycle.example.com/bundle.tgz' },
                  droplet_destinations: { 'default-stack-name': '/home/vcap' },
                  enable_declarative_asset_downloads: false
                }
              })
            end

            it 'returns a docker:// rootfs URI for the private registry' do
              expect(builder.root_fs).to eq('docker://registry.example.com/my-org/my-stack#v2.0')
            end
          end
        end

        describe '#cached_dependencies' do
          context 'with a custom stack' do
            let(:stack) { 'docker://docker.io/cloudfoundry/cflinuxfs4:1.268.0' }
            let(:config) do
              Config.new({
                diego: {
                  use_privileged_containers_for_running: false,
                  lifecycle_bundles: { "buildpack/#{VCAP::CloudController::Stack.default.name}": 'http://lifecycle.example.com/bundle.tgz' },
                  droplet_destinations: { 'default-stack-name': '/home/vcap' },
                  enable_declarative_asset_downloads: false
                }
              })
            end

            it 'uses the default stack lifecycle bundle' do
              allow(LifecycleBundleUriGenerator).to receive(:uri).and_return('http://lifecycle.example.com/bundle.tgz')
              deps = builder.cached_dependencies
              expect(deps.first.cache_key).to eq("buildpack-#{VCAP::CloudController::Stack.default.name}-lifecycle")
            end
          end
        end

        describe '#image_layers' do
          let(:config) do
            Config.new({
              diego: {
                use_privileged_containers_for_running: false,
                lifecycle_bundles: { "buildpack/#{VCAP::CloudController::Stack.default.name}": 'http://lifecycle.example.com/bundle.tgz' },
                droplet_destinations: { 'default-stack-name': '/home/vcap' },
                enable_declarative_asset_downloads: true
              }
            })
          end

          context 'with a custom stack' do
            let(:stack) { 'docker://docker.io/cloudfoundry/cflinuxfs4:1.268.0' }

            it 'uses the default stack for lifecycle bundle and droplet destination' do
              allow(LifecycleBundleUriGenerator).to receive(:uri).and_return('http://lifecycle.example.com/bundle.tgz')
              layers = builder.image_layers
              lifecycle_layer = layers.find { |l| l.name.include?('lifecycle') }
              expect(lifecycle_layer.name).to eq('buildpack-default-stack-name-lifecycle')
            end
          end
        end
      end
    end
  end
end
