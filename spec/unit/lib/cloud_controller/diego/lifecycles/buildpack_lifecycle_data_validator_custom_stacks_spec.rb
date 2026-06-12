require 'spec_helper'
require 'cloud_controller/diego/lifecycles/buildpack_lifecycle_data_validator'

module VCAP::CloudController
  RSpec.describe BuildpackLifecycleDataValidator do
    let(:stack) { Stack.make }
    let(:buildpack_url) { 'https://github.com/my-org/my-buildpack.git' }
    let(:buildpack_info) { BuildpackInfo.new(buildpack_url, nil) }
    let(:buildpack_infos) { [buildpack_info] }

    subject(:validator) do
      BuildpackLifecycleDataValidator.new(
        buildpack_infos: buildpack_infos,
        stack: stack,
        stack_name: stack&.name
      )
    end

    describe 'custom stacks' do
      let(:stack) { nil }
      let(:custom_stack_uri) { 'docker://docker.io/cloudfoundry/cflinuxfs4:1.268.0' }

      subject(:validator) do
        BuildpackLifecycleDataValidator.new(
          buildpack_infos: buildpack_infos,
          stack: nil,
          stack_name: custom_stack_uri
        )
      end

      context 'when diego_custom_stacks feature flag is enabled' do
        before do
          FeatureFlag.make(name: 'diego_custom_stacks', enabled: true)
        end

        context 'with custom buildpacks (URL-based)' do
          let(:buildpack_info) { BuildpackInfo.new('https://github.com/my-org/my-buildpack.git', nil) }

          it 'is valid' do
            expect(validator).to be_valid
          end
        end

        context 'with admin buildpacks (not URL-based, no record)' do
          let(:buildpack_info) { BuildpackInfo.new('ruby_buildpack', nil) }

          it 'is not valid' do
            expect(validator).not_to be_valid
            expect(validator.errors[:buildpack]).to include('must be a custom buildpack (URL) when using a custom stack')
          end
        end
      end

      context 'when diego_custom_stacks feature flag is disabled' do
        before do
          FeatureFlag.make(name: 'diego_custom_stacks', enabled: false)
        end

        it 'is not valid (stack must exist in DB)' do
          expect(validator).not_to be_valid
          expect(validator.errors[:stack]).to include('must be an existing stack')
        end
      end
    end

    describe 'system stacks (unchanged behavior)' do
      context 'when stack exists in DB' do
        it 'is valid' do
          expect(validator).to be_valid
        end
      end

      context 'when stack does not exist in DB' do
        let(:stack) { nil }

        subject(:validator) do
          BuildpackLifecycleDataValidator.new(
            buildpack_infos: buildpack_infos,
            stack: nil,
            stack_name: 'nonexistent-stack'
          )
        end

        it 'is not valid' do
          expect(validator).not_to be_valid
          expect(validator.errors[:stack]).to include('must be an existing stack')
        end
      end
    end
  end
end
