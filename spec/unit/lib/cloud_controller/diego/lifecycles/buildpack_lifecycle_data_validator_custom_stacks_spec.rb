require 'spec_helper'
require 'cloud_controller/diego/lifecycles/buildpack_lifecycle_data_validator'

module VCAP::CloudController
  RSpec.describe BuildpackLifecycleDataValidator do
    let(:stack) { create(:stack) }
    let(:buildpack_url) { 'https://github.com/my-org/my-buildpack.git' }
    let(:buildpack_info) { BuildpackInfo.new(buildpack_url, nil) }
    let(:buildpack_infos) { [buildpack_info] }
    let(:lifecycle_type) { Lifecycles::BUILDPACK }

    subject(:validator) do
      BuildpackLifecycleDataValidator.new(
        buildpack_infos: buildpack_infos,
        stack: stack,
        stack_name: stack&.name,
        lifecycle_type: lifecycle_type
      )
    end

    describe 'custom stacks' do
      let(:stack) { nil }
      let(:custom_stack_uri) { 'docker://docker.io/cloudfoundry/cflinuxfs4:1.268.0' }

      subject(:validator) do
        BuildpackLifecycleDataValidator.new(
          buildpack_infos: buildpack_infos,
          stack: nil,
          stack_name: custom_stack_uri,
          lifecycle_type: lifecycle_type
        )
      end

      context 'when diego_custom_stacks feature flag is enabled' do
        before do
          create(:feature_flag, name: 'diego_custom_stacks', enabled: true)
        end

        context 'with custom buildpacks (URL-based)' do
          let(:buildpack_info) { BuildpackInfo.new('https://github.com/my-org/my-buildpack.git', nil) }

          it 'is valid' do
            expect(validator).to be_valid
          end
        end

        context 'with an unpinned admin buildpack' do
          let(:buildpack_info) { BuildpackInfo.new('ruby_buildpack', create(:buildpack, :nil_stack, name: 'ruby_buildpack')) }

          it 'is valid' do
            expect(validator).to be_valid
          end
        end

        context 'when auto-detecting without an enabled unpinned admin buildpack' do
          let(:buildpack_infos) { [] }

          it 'is not valid' do
            expect(validator).not_to be_valid
            expect(validator.errors[:buildpack]).to include(
              'must specify a custom buildpack URL or an enabled unpinned admin buildpack when using a custom stack'
            )
          end
        end

        context 'when auto-detecting with an enabled unpinned admin buildpack' do
          let(:buildpack_infos) { [] }

          before do
            create(:buildpack, :nil_stack, enabled: true)
          end

          it 'is valid' do
            expect(validator).to be_valid
          end
        end

        context 'when auto-detecting CNB buildpacks' do
          let(:lifecycle_type) { Lifecycles::CNB }
          let(:buildpack_infos) { [] }

          before do
            create(:buildpack, :nil_stack, lifecycle: Lifecycles::BUILDPACK)
          end

          it 'does not use an unpinned buildpack lifecycle admin buildpack' do
            expect(validator).not_to be_valid
            expect(validator.errors[:buildpack]).to include(
              'must specify a custom buildpack URL or an enabled unpinned admin buildpack when using a custom stack'
            )
          end
        end

        context 'with credentials embedded in the stack URI' do
          let(:custom_stack_uri) { 'docker://user:pass@registry.example.com/org/stack:tag' }

          it 'is not valid' do
            expect(validator).not_to be_valid
            expect(validator.errors[:stack]).to include('Custom stack URIs must not contain credentials; use data.credentials instead')
          end
        end

        context 'with an invalid custom stack URI' do
          let(:custom_stack_uri) { 'docker://registry.example.com/' }

          it 'reports an invalid container image URI' do
            expect(validator).not_to be_valid
            expect(validator.errors[:stack]).to contain_exactly('must be a valid container image URI')
          end
        end
      end

      context 'when diego_custom_stacks feature flag is disabled' do
        before do
          create(:feature_flag, name: 'diego_custom_stacks', enabled: false)
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
