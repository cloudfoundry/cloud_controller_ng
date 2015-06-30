require 'spec_helper'
require 'messages/buildpack_request_validator'

module VCAP::CloudController
  describe BuildpackRequestValidator do
    context 'when a bad url is requested and it does not match the name of an admin buildpack' do
      let(:params) { { buildpack: 'blagow!' } }

      it 'is not valid' do
        message = BuildpackRequestValidator.new(params)

        expect(message).not_to be_valid
        expect(message.errors_on(:buildpack)).to include('must be an existing admin buildpack or a valid git URI')
      end
    end

    context 'when buildpack matches the name of an admin buildpack' do
      let(:admin_buildpack) { Buildpack.make }
      let(:params) { { buildpack: admin_buildpack.name } }

      it 'is valid' do
        message = BuildpackRequestValidator.new(params)

        expect(message).to be_valid
      end
    end

    context 'when buildpack is nil' do
      let(:params) { { buildpack: nil } }

      it 'is valid' do
        message = BuildpackRequestValidator.new(params)

        expect(message).to be_valid
      end
    end
  end
end
