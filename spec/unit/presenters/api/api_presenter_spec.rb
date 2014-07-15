require 'spec_helper'
require 'presenters/api/api_presenter'

describe ApiPresenter do
  let(:created_at) { 10.minutes.ago }
  let(:updated_at) { 5.minutes.ago }
  let(:record) { double('record', guid: '12345ac', created_at: created_at, updated_at: updated_at) }

  subject(:presenter) { ApiPresenter.new(record) }

  describe '#to_hash' do
    describe '[:metadata]' do
      subject(:metadata) { presenter.to_hash.fetch(:metadata) }

      it 'includes the guid and timestamps' do
        expect(metadata.fetch(:guid)).to eq('12345ac')
        expect(metadata.fetch(:created_at)).to eq(created_at.iso8601)
        expect(metadata.fetch(:updated_at)).to eq(updated_at.iso8601)
      end
    end

    describe '[:entity]' do
      subject(:entity) { presenter.to_hash.fetch(:entity) }

      it 'exists' do
        expect(entity).to be
      end
    end
  end

  describe '#to_json' do
    it 'returns the hash as serialized JSON' do
      expect(presenter.to_json).to eq(MultiJson.dump(presenter.to_hash, :pretty => true))
    end
  end
end
