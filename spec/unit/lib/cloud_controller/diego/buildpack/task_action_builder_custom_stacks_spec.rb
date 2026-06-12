require 'spec_helper'
require 'cloud_controller/diego/buildpack/task_action_builder'
require 'cloud_controller/diego/custom_stack_uri_converter'

module VCAP::CloudController
  module Diego
    module Buildpack
      RSpec.describe TaskActionBuilder do
        let(:stack_name) { 'cflinuxfs4' }
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
        let(:lifecycle_data) do
          {
            droplet_uri: 'http://droplet.example.com/droplet.tgz',
            stack: stack_name
          }
        end
        let(:task) do
          instance_double(TaskModel,
            name: 'my-task',
            droplet: instance_double(DropletModel, sha256_checksum: 'abc123', droplet_hash: 'hash'))
        end

        subject(:builder) do
          TaskActionBuilder.new(config, task, lifecycle_data, 'vcap', ['app', 'echo hello', ''], 'buildpack')
        end

        before do
          VCAP::CloudController::Stack.find(name: 'cflinuxfs4') || VCAP::CloudController::Stack.create(name: 'cflinuxfs4')
        end

        describe '#stack' do
          context 'with a system stack' do
            it 'returns preloaded rootfs' do
              expect(builder.stack).to eq('preloaded:cflinuxfs4')
            end
          end

          context 'with a custom stack' do
            let(:stack_name) { 'docker://docker.io/cloudfoundry/cflinuxfs4:1.268.0' }

            it 'returns a docker:// rootfs URI' do
              expect(builder.stack).to eq('docker://docker.io/cloudfoundry/cflinuxfs4#1.268.0')
            end
          end
        end

        describe '#lifecycle_bundle_key' do
          context 'with a system stack' do
            it 'uses the stack name' do
              expect(builder.lifecycle_bundle_key).to eq(:"buildpack/cflinuxfs4")
            end
          end

          context 'with a custom stack' do
            let(:stack_name) { 'docker://docker.io/cloudfoundry/cflinuxfs4:1.268.0' }

            it 'falls back to the default stack name' do
              expect(builder.lifecycle_bundle_key).to eq(:"buildpack/#{VCAP::CloudController::Stack.default.name}")
            end
          end
        end

        describe '#cached_dependencies' do
          context 'with a custom stack' do
            let(:stack_name) { 'docker://registry.example.com/my-stack:v1' }

            it 'uses the default stack lifecycle bundle' do
              allow(LifecycleBundleUriGenerator).to receive(:uri).and_return('http://lifecycle.example.com/bundle.tgz')
              deps = builder.cached_dependencies
              expect(deps.first.cache_key).to eq("buildpack-#{VCAP::CloudController::Stack.default.name}-lifecycle")
            end
          end
        end
      end
    end
  end
end
