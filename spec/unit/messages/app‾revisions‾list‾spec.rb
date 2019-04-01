require 'spec_helper'
require 'messages/app_revisions_list_message'

module VCAP::CloudController
  RSpec.describe AppRevisionsListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'versions' => '808,810',
          'page' => 1,
          'per_page' => 5,
          'order_by' => 'created_at',
          }
      end

      it 'returns the correct AppRevisionsListMessage' do
        message = AppRevisionsListMessage.from_params(params)

        expect(message).to be_a(AppRevisionsListMessage)
        expect(message.page).to eq(1)
        expect(message.versions).to contain_exactly('808', '810')
        expect(message.per_page).to eq(5)
        expect(message.order_by).to eq('created_at')
      end

      it 'converts requested keys to symbols' do
        message = AppRevisionsListMessage.from_params(params)

        expect(message.requested?(:versions)).to be_truthy
        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
        expect(message.requested?(:order_by)).to be_truthy
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        expect {
          AppRevisionsListMessage.from_params({
            versions: [],
            page: 1,
            per_page: 5,
            order_by: 'created_at',
          })
        }.not_to raise_error
      end

      it 'accepts an empty set' do
        message = AppRevisionsListMessage.from_params({})
        expect(message).to be_valid
      end

      describe 'validations' do
        it 'validates versions is an array' do
          message = AppRevisionsListMessage.from_params(versions: 'not array')
          expect(message).to be_invalid
          expect(message.errors[:versions].length).to eq 1
        end
      end
    end
  end
end
