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

    context 'when the buildpack is a valid url' do
      let(:url) { 'http://buildpack-url.git' }
      let(:params) { { buildpack: url } }

      it 'is valid and saves the url' do
        message = BuildpackRequestValidator.new(params)
        expect(message).to be_valid
        expect(message.buildpack_url).to eq(url)
      end
    end

    context 'when buildpack matches the name of an admin buildpack' do
      let(:admin_buildpack) { Buildpack.make }
      let(:params) { { buildpack: admin_buildpack.name } }

      it 'is valid' do
        message = BuildpackRequestValidator.new(params)

        expect(message).to be_valid
      end

      it 'saves off the buildpack' do
        message = BuildpackRequestValidator.new(params)
        message.valid?

        expect(message.buildpack_record).to eq(admin_buildpack)
      end
    end

    context 'when buildpack is nil' do
      let(:params) { { buildpack: nil } }

      it 'is valid' do
        message = BuildpackRequestValidator.new(params)

        expect(message).to be_valid
      end
    end

    describe '#to_s' do
      let(:validator) { BuildpackRequestValidator.new }

      context 'when there is a buildpack_url' do
        before { validator.buildpack_url = 'a-url' }

        it 'returns the url' do
          expect(validator.to_s).to eq('a-url')
        end
      end

      context 'when there is a buildpack_record' do
        let(:buildpack) { Buildpack.make }
        before { validator.buildpack_record = buildpack }

        it 'returns the name from the record' do
          expect(validator.to_s).to eq(buildpack.name)
        end
      end

      context 'when there is neither a url nor a record' do
        it 'returns nil' do
          expect(validator.to_s).to eq(nil)
        end
      end
    end
  end
end
