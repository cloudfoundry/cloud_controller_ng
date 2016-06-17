require 'spec_helper'
require 'cloud_controller/diego/lifecycles/buildpack_lifecycle_data_validator'

module VCAP::CloudController
  RSpec.describe BuildpackLifecycleDataValidator do
    subject(:validator) { BuildpackLifecycleDataValidator.new({ stack: stack, buildpack_info: buildpack_info }) }
    let(:stack) { Stack.make }
    let(:buildpack) { Buildpack.make }
    let(:buildpack_name_or_url) { buildpack.name }
    let(:buildpack_info) { BuildpackInfo.new(buildpack_name_or_url, buildpack) }

    context 'when stack is nil' do
      let(:stack) { nil }

      it 'is not valid' do
        expect(validator).not_to be_valid
        expect(validator.errors_on(:stack)).to include('must be an existing stack')
      end
    end

    context 'when buildpack_info has a buildpack_url' do
      let(:buildpack_name_or_url) { 'http://yeah.com' }
      let(:buildpack) { nil }

      it 'is valid' do
        expect(validator). to be_valid
      end
    end

    context 'when buildpack_info buildpack is nil' do
      let(:buildpack_name_or_url) { nil }
      let(:buildpack) { nil }

      it 'is valid' do
        expect(validator).to be_valid
      end
    end

    context 'when buildpack_info buildpack is a buildpack name' do
      let(:buildpack_name_or_url) { buildpack.name }

      it 'is valid' do
        expect(validator).to be_valid
      end

      context 'but there is buildpack_record on buildpack_info' do
        let(:buildpack_name_or_url) { 'some-name' }
        let(:buildpack) { nil }

        it 'is not valid' do
          expect(validator).not_to be_valid
        end
      end
    end
  end
end
