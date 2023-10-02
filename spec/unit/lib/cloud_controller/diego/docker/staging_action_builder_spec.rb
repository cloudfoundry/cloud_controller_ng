require 'spec_helper'

module VCAP::CloudController
  module Diego
    module Docker
      RSpec.describe StagingActionBuilder do
        subject(:builder) { StagingActionBuilder.new(config, staging_details) }

        let(:config) do
          Config.new({
                       diego: {
                         docker_staging_stack: 'docker-staging-stack',
                         lifecycle_bundles: {
                           docker: 'the-docker-bundle'
                         },
                         enable_declarative_asset_downloads: enable_declarative_asset_downloads,
                         insecure_docker_registry_list: []
                       },
                       staging: {
                         minimum_staging_file_descriptor_limit: 4
                       }
                     })
        end
        let(:staging_details) do
          StagingDetails.new.tap do |details|
            details.package = PackageModel.new(docker_image: 'the-docker-image')
            details.environment_variables = env
          end
        end
        let(:env) { double(:env) }
        let(:generated_environment) { [::Diego::Bbs::Models::EnvironmentVariable.new(name: 'generated-environment', value: 'generated-value')] }
        let(:enable_declarative_asset_downloads) { false }

        before do
          allow(LifecycleBundleUriGenerator).to receive(:uri).with('the-docker-bundle').and_return('generated-uri')
          allow(BbsEnvironmentBuilder).to receive(:build).with(env).and_return(generated_environment)
        end

        describe '#action' do
          it 'returns the correct docker staging action structure' do
            result = builder.action

            emit_progress = result.emit_progress_action
            expect(emit_progress.start_message).to eq('Staging...')
            expect(emit_progress.success_message).to eq('Staging Complete')
            expect(emit_progress.failure_message_prefix).to eq('Staging Failed')

            run_action = emit_progress.action.run_action
            expect(run_action.path).to eq('/tmp/lifecycle/builder')
            expect(run_action.user).to eq('vcap')
            expect(run_action.env).to eq(generated_environment)
            expect(run_action.args).to contain_exactly('-outputMetadataJSONFilename=/tmp/result.json', '-dockerRef=the-docker-image')
            expect(run_action.resource_limits).to eq(::Diego::Bbs::Models::ResourceLimits.new(nofile: 4))
          end

          context 'when there are insecure docker registries' do
            before do
              config.set(:diego, config.get(:diego).deep_merge(insecure_docker_registry_list: %w[registry-1 registry-2]))
            end

            it 'includes them in the run action args' do
              result = builder.action

              run_action = result.emit_progress_action.action.run_action
              expect(run_action.args).to include('-insecureDockerRegistries=registry-1,registry-2')
            end
          end

          context 'where there are docker credentials' do
            let(:staging_details) do
              StagingDetails.new.tap do |details|
                details.package = PackageModel.new(
                  docker_image: 'the-docker-image',
                  docker_username: 'dockerusername',
                  docker_password: 'dockerpassword'
                )
                details.environment_variables = env
              end
            end

            it 'includes them in the run action args' do
              result = builder.action

              run_action = result.emit_progress_action.action.run_action
              expect(run_action.args).to include('-dockerUser=dockerusername')
              expect(run_action.args).to include('-dockerPassword=dockerpassword')
            end
          end
        end

        describe '#cached_dependencies' do
          it 'returns an array with the docker lifecycle bundle dependency' do
            result = builder.cached_dependencies

            expect(result.count).to eq(1)
            lifecycle_dependency = result.first

            expect(lifecycle_dependency.to).to eq('/tmp/lifecycle')
            expect(lifecycle_dependency.cache_key).to eq('docker-lifecycle')
            expect(lifecycle_dependency.from).to eq('generated-uri')
          end

          context 'when enable_declarative_asset_downloads is true' do
            let(:enable_declarative_asset_downloads) { true }

            it 'returns nil' do
              expect(builder.cached_dependencies).to be_nil
            end
          end
        end

        describe '#image_layers' do
          it 'returns empty array' do
            expect(builder.image_layers).to be_empty
          end

          context 'when enable_declarative_asset_downloads is true' do
            let(:enable_declarative_asset_downloads) { true }

            it 'creates a image layer for each cached dependency' do
              expect(builder.image_layers).to include(
                ::Diego::Bbs::Models::ImageLayer.new(
                  name: 'docker-lifecycle',
                  url: 'generated-uri',
                  destination_path: '/tmp/lifecycle',
                  layer_type: ::Diego::Bbs::Models::ImageLayer::Type::SHARED,
                  media_type: ::Diego::Bbs::Models::ImageLayer::MediaType::TGZ
                )
              )
            end
          end
        end

        describe '#stack' do
          it 'returns the configured docker_staging_stack' do
            expect(builder.stack).to eq('preloaded:docker-staging-stack')
          end
        end

        describe '#task_environment_variables' do
          it 'exists' do
            expect { builder.task_environment_variables }.not_to raise_error
          end
        end
      end
    end
  end
end
