require 'spec_helper'
require 'cloud_controller/diego/task_recipe_builder'

module VCAP::CloudController
  module Diego
    RSpec.describe TaskRecipeBuilder do
      subject(:task_recipe_builder) { TaskRecipeBuilder.new }

      describe '#staging_image_username / #staging_image_password (custom stacks)' do
        let(:custom_stack_uri) { 'docker://registry.example.com/my-org/my-stack:v1.0' }
        let(:lifecycle) do
          instance_double(
            BuildpackLifecycle,
            staging_stack: custom_stack_uri,
            credentials: {
              'registry.example.com' => {
                'username' => 'my-user',
                'password' => 'my-pass'
              }
            }
          )
        end
        let(:package) do
          instance_double(PackageModel, docker_username: nil, docker_password: nil)
        end
        let(:staging_details) do
          instance_double(StagingDetails, package: package, lifecycle: lifecycle)
        end

        it 'returns credentials from the custom stack lifecycle' do
          expect(task_recipe_builder.send(:staging_image_username, staging_details)).to eq('my-user')
          expect(task_recipe_builder.send(:staging_image_password, staging_details)).to eq('my-pass')
        end
      end

      describe '#staging_image_username / #staging_image_password (docker package)' do
        let(:lifecycle) do
          instance_double(
            BuildpackLifecycle,
            staging_stack: 'cflinuxfs4',
            credentials: nil
          )
        end
        let(:package) do
          instance_double(PackageModel, docker_username: 'docker-user', docker_password: 'docker-pass')
        end
        let(:staging_details) do
          instance_double(StagingDetails, package: package, lifecycle: lifecycle)
        end

        it 'uses docker package credentials when both are present' do
          expect(task_recipe_builder.send(:staging_image_username, staging_details)).to eq('docker-user')
          expect(task_recipe_builder.send(:staging_image_password, staging_details)).to eq('docker-pass')
        end
      end

      describe '#staging_image_username / #staging_image_password (mismatched docker credentials)' do
        let(:lifecycle) do
          instance_double(
            BuildpackLifecycle,
            staging_stack: 'docker://registry.example.com/my-org/my-stack:v1.0',
            credentials: {
              'registry.example.com' => {
                'username' => 'stack-user',
                'password' => 'stack-pass'
              }
            }
          )
        end
        let(:package) do
          instance_double(PackageModel, docker_username: 'only-user', docker_password: nil)
        end
        let(:staging_details) do
          instance_double(StagingDetails, package: package, lifecycle: lifecycle)
        end

        it 'falls through to custom stack credentials when docker pair is incomplete' do
          expect(task_recipe_builder.send(:staging_image_username, staging_details)).to eq('stack-user')
          expect(task_recipe_builder.send(:staging_image_password, staging_details)).to eq('stack-pass')
        end
      end

      describe '#task_image_username / #task_image_password (custom stacks)' do
        let(:lifecycle_data) do
          instance_double(
            BuildpackLifecycleDataModel,
            stack: 'docker://registry.example.com/my-org/my-stack:v1.0',
            credentials: {
              'registry.example.com' => {
                'username' => 'task-user',
                'password' => 'task-pass'
              }
            }
          )
        end
        let(:app_model) do
          instance_double(AppModel, lifecycle_data: lifecycle_data)
        end
        let(:droplet) do
          instance_double(DropletModel, docker_receipt_username: nil, docker_receipt_password: nil)
        end
        let(:task) do
          instance_double(TaskModel, app: app_model, droplet: droplet)
        end

        it 'returns credentials from the custom stack lifecycle data' do
          expect(task_recipe_builder.send(:task_image_username, task)).to eq('task-user')
          expect(task_recipe_builder.send(:task_image_password, task)).to eq('task-pass')
        end
      end

      describe '#task_image_username / #task_image_password (docker droplet)' do
        let(:lifecycle_data) do
          instance_double(BuildpackLifecycleDataModel, stack: 'cflinuxfs4', credentials: nil)
        end
        let(:app_model) do
          instance_double(AppModel, lifecycle_data: lifecycle_data)
        end
        let(:droplet) do
          instance_double(DropletModel, docker_receipt_username: 'droplet-user', docker_receipt_password: 'droplet-pass')
        end
        let(:task) do
          instance_double(TaskModel, app: app_model, droplet: droplet)
        end

        it 'uses docker receipt credentials when both are present' do
          expect(task_recipe_builder.send(:task_image_username, task)).to eq('droplet-user')
          expect(task_recipe_builder.send(:task_image_password, task)).to eq('droplet-pass')
        end
      end
    end
  end
end
