require 'spec_helper'

RSpec.describe MetadataPolicy do
  let(:app) { VCAP::CloudController::AppFactory.make }

  subject(:validator) { MetadataPolicy.new(app, metadata) }

  context 'when metadata is a hash' do
    let(:metadata) { {} }

    it 'does not register error' do
      expect(validator).to validate_without_error(app)
    end
  end

  context 'when metadata is nil' do
    let(:metadata) { nil }

    it 'does not register error' do
      expect(validator).to validate_without_error(app)
    end
  end

  context 'when metadata is a string' do
    let(:metadata) { 'not metadata' }

    it 'registers error' do
      expect(validator).to validate_with_error(app, :metadata, :invalid_metadata)
    end
  end

  context 'when metadata is an array' do
    let(:metadata) { [] }

    it 'registers error' do
      expect(validator).to validate_with_error(app, :metadata, :invalid_metadata)
    end
  end

  context 'when metadata is a hash with multiple variables' do
    let(:metadata) { { abc: 123, def: 'hi' } }

    it 'does not register error' do
      expect(validator).to validate_without_error(app)
    end
  end
end
