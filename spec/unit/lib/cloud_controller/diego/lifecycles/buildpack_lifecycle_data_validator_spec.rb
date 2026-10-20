require 'spec_helper'
require 'cloud_controller/diego/lifecycles/buildpack_lifecycle_data_validator'

module VCAP::CloudController
  RSpec.describe BuildpackLifecycleDataValidator do
    subject(:validator) { BuildpackLifecycleDataValidator.new({ stack:, buildpack_infos: }) }
    let(:stack) { create(:stack) }
    let(:buildpack) { create(:buildpack) }
    let(:buildpack_name_or_url) { buildpack.name }
    let(:buildpack_info) { BuildpackInfo.new(buildpack_name_or_url, buildpack) }
    let(:buildpack_infos) { [buildpack_info] }

    context 'when stack is nil' do
      let(:stack) { nil }

      it 'is not valid' do
        expect(validator).not_to be_valid
        expect(validator.errors_on(:stack)).to include('must be an existing stack')
      end
    end

    context 'when stack is nil and buildpack is nonexistant' do
      let(:stack) { nil }
      let(:buildpack_name_or_url) { 'nonexistant_buildpack' }
      let(:buildpack) { nil }

      it 'is not valid' do
        expect(validator).not_to be_valid
        expect(validator.errors_on(:stack)).to include('must be an existing stack')
        expect(validator.errors_on(:buildpack)).to include('"nonexistant_buildpack" must be an existing admin buildpack or a valid git URI')
      end
    end

    context 'when given a buildpack url' do
      let(:buildpack_name_or_url) { 'http://yeah.com' }
      let(:buildpack) { nil }

      it 'is valid' do
        expect(validator).to be_valid
      end
    end

    context 'when given an empty BuildpackInfo' do
      let(:buildpack_name_or_url) { nil }
      let(:buildpack) { nil }

      it 'is valid' do
        expect(validator).to be_valid
      end
    end

    context 'when given an admin buildpack' do
      let(:buildpack_name_or_url) { buildpack.name }

      it 'is valid' do
        expect(validator).to be_valid
      end
    end

    context 'when given neither an admin buildpack or buildpack url' do
      let(:buildpack_name_or_url) { 'some-name' }
      let(:buildpack) { nil }

      it 'is not valid' do
        expect(validator).not_to be_valid
      end
    end

    context 'when given multiple buildpack infos' do
      let(:buildpack_infos) { [buildpack_info, BuildpackInfo.new('http://valid-buildpack.example.com', nil)] }

      it 'is valid' do
        expect(validator).to be_valid
      end

      context 'when given an invalid BuildpackInfo' do
        let(:buildpack_infos) { [buildpack_info, BuildpackInfo.new('invalid-bp', nil)] }
        let(:stack) { create(:stack, name: 'existing_stack') }

        it 'includes an error for the invalid buildpack' do
          expect(validator).not_to be_valid
          expect(validator.errors[:buildpack]).to include('"invalid-bp" for stack "existing_stack" must be an existing admin buildpack or a valid git URI')
        end
      end
    end

    describe 'rejects buildpack URL userinfo combined with data.credentials' do
      let(:url_with_creds_info) { BuildpackInfo.new('https://user:pass@git.example.com/acme/bp.git', nil) }
      let(:url_without_creds_info) { BuildpackInfo.new('https://git.example.com/acme/bp.git', nil) }

      context 'when the conflicting credentials were supplied in this request' do
        it 'reports the both-in-one-request message' do
          validator = BuildpackLifecycleDataValidator.new(
            buildpack_infos: [url_with_creds_info],
            stack: create(:stack),
            credentials: { 'git.example.com' => { 'username' => 'u', 'password' => 'p' } },
            credentials_from_message: true
          )
          expect(validator).not_to be_valid
          expect(validator.errors.full_messages.join).to include('either in the buildpack URI or in data.credentials, not both')
        end
      end

      context 'when the conflicting credentials are stored (not in this request)' do
        it 'tells the user how to clear the stored credentials' do
          validator = BuildpackLifecycleDataValidator.new(
            buildpack_infos: [url_with_creds_info],
            stack: create(:stack),
            credentials: { 'git.example.com' => { 'username' => 'u', 'password' => 'p' } },
            credentials_from_message: false
          )
          expect(validator).not_to be_valid
          expect(validator.errors.full_messages.join).to include('already has stored buildpack credentials')
          expect(validator.errors.full_messages.join).to include('credentials: null')
        end
      end

      context 'when buildpack URL has userinfo and no data.credentials' do
        it 'is valid' do
          validator = BuildpackLifecycleDataValidator.new(
            buildpack_infos: [url_with_creds_info],
            stack: create(:stack),
            credentials: nil
          )
          expect(validator).to be_valid
        end
      end

      context 'when buildpack URL is clean and data.credentials are set' do
        it 'is valid' do
          validator = BuildpackLifecycleDataValidator.new(
            buildpack_infos: [url_without_creds_info],
            stack: create(:stack),
            credentials: { 'git.example.com' => { 'username' => 'u', 'password' => 'p' } }
          )
          expect(validator).to be_valid
        end
      end

      context 'when buildpack URL is clean and no data.credentials' do
        it 'is valid' do
          validator = BuildpackLifecycleDataValidator.new(
            buildpack_infos: [url_without_creds_info],
            stack: create(:stack),
            credentials: nil
          )
          expect(validator).to be_valid
        end
      end
    end
  end
end
