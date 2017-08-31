require 'spec_helper'

module VCAP::CloudController
  module Diego
    module Docker
      RSpec.describe StagingActionBuilder do
        subject(:builder) { StagingActionBuilder.new(config, staging_details) }

        let(:config) do
          Config.new({
            diego:   {
              docker_staging_stack:          'docker-staging-stack',
              lifecycle_bundles:             {
                docker: 'the-docker-bundle'
              },
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
            expect(run_action.path).to eq('/tmp/docker_app_lifecycle/builder')
            expect(run_action.user).to eq('vcap')
            expect(run_action.env).to eq(generated_environment)
            expect(run_action.args).to match_array(['-outputMetadataJSONFilename=/tmp/result.json', '-dockerRef=the-docker-image'])
            expect(run_action.resource_limits).to eq(::Diego::Bbs::Models::ResourceLimits.new(nofile: 4))
          end

          context 'when there are insecure docker registries' do
            before do
              config.set(:diego, config.get(:diego).deep_merge(insecure_docker_registry_list: ['registry-1', 'registry-2']))
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
                  docker_password: 'dockerpassword',
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

            expect(lifecycle_dependency.to).to eq('/tmp/docker_app_lifecycle')
            expect(lifecycle_dependency.cache_key).to eq('docker-lifecycle')
            expect(lifecycle_dependency.from).to eq('generated-uri')
          end
        end

        describe '#stack' do
          it 'returns the configured docker_staging_stack' do
            expect(builder.stack).to eq('docker-staging-stack')
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
