require 'spec_helper'
require 'cloud_controller/diego/lifecycles/buildpack_lifecycle_data_validator'

module VCAP::CloudController
  RSpec.describe BuildpackLifecycleDataValidator do
    subject(:validator) { BuildpackLifecycleDataValidator.new({ stack: stack, buildpack_infos: buildpack_infos }) }
    let(:stack) { Stack.make }
    let(:buildpack) { Buildpack.make }
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

        it 'includes an error for the invalid buildpack' do
          expect(validator).not_to be_valid
          expect(validator.errors[:buildpack]).to include('"invalid-bp" must be an existing admin buildpack or a valid git URI')
        end
      end
    end
  end
end
