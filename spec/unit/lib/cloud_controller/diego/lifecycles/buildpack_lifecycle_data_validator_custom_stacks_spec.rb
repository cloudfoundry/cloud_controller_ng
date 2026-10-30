require 'spec_helper'
require 'cloud_controller/diego/lifecycles/buildpack_lifecycle_data_validator'

module VCAP::CloudController
  RSpec.describe BuildpackLifecycleDataValidator do
    let(:buildpack_url) { 'https://github.com/my-org/my-buildpack.git' }
    let(:buildpack_info) { BuildpackInfo.new(buildpack_url, nil) }
    let(:buildpack_infos) { [buildpack_info] }
    let(:lifecycle_type) { Lifecycles::BUILDPACK }
    let(:credentials) { nil }

    describe 'custom stacks' do
      let(:custom_stack_uri) { 'docker://docker.io/cloudfoundry/cflinuxfs4:1.268.0' }

      subject(:validator) do
        BuildpackLifecycleDataValidator.new(
          buildpack_infos: buildpack_infos,
          stack: nil,
          stack_name: custom_stack_uri,
          lifecycle_type: lifecycle_type,
          credentials: credentials
        )
      end

      context 'when diego_custom_stacks feature flag is enabled' do
        before do
          create(:feature_flag, name: 'diego_custom_stacks', enabled: true)
        end

        it 'accepts a custom buildpack URL' do
          expect(validator).to be_valid
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
            expect(validator.errors.full_messages).to include(
              'You must either specify a custom buildpack URL or your platform operator must provide an enabled buildpack that is not pinned to a stack'
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
            expect(validator.errors.full_messages).to include(
              'You must either specify a custom buildpack URL or your platform operator must provide an enabled buildpack that is not pinned to a stack'
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

        context 'with registry credentials' do
          let(:custom_stack_uri) { 'docker://registry.example.com/team/stack:latest' }
          let(:registry_credentials) { { 'username' => 'registry-user', 'password' => 'registry-pass' } }
          let(:credentials) { { 'registry.example.com' => registry_credentials } }

          it 'accepts string credentials' do
            expect(validator).to be_valid
          end

          %w[username password].each do |field|
            context "with a non-string #{field}" do
              let(:registry_credentials) { super().merge(field => 123) }

              it 'rejects the value without exposing it in the error' do
                expect(validator).not_to be_valid
                expect(validator.errors[:credentials]).to contain_exactly("#{field} for custom stack registry \"registry.example.com\" must be a string")
              end
            end
          end

          context 'with null credential fields' do
            let(:registry_credentials) { { 'username' => nil, 'password' => nil } }

            it 'preserves support for absent credentials' do
              expect(validator).to be_valid
            end
          end

          context 'with CNB token credentials for a buildpack registry' do
            let(:lifecycle_type) { Lifecycles::CNB }
            let(:credentials) { super().merge('buildpacks.example.com' => { 'token' => 'buildpack-token' }) }

            it 'accepts tokens separately from the stack credentials' do
              expect(validator).to be_valid
            end
          end
        end

        context 'with an invalid custom stack URI' do
          let(:custom_stack_uri) { 'docker://registry.example.com/team/' }

          it 'reports an invalid container image URI' do
            expect(validator).not_to be_valid
            expect(validator.errors.full_messages).to contain_exactly('Stack must be a valid container image URI starting with "docker://"')
          end
        end

        context 'with a stack that is neither an existing stack nor a valid custom stack URI' do
          let(:custom_stack_uri) { 'ocker://registry.example.com/org/stack:tag' }

          it 'reports both supported stack formats' do
            expect(validator).not_to be_valid
            expect(validator.errors.full_messages).to contain_exactly(
              'Stack must be an existing stack or a valid container image URI starting with "docker://"'
            )
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
  end
end
