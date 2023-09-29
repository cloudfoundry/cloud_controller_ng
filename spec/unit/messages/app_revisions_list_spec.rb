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
          'order_by' => 'created_at'
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

        expect(message).to be_requested(:versions)
        expect(message).to be_requested(:page)
        expect(message).to be_requested(:per_page)
        expect(message).to be_requested(:order_by)
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        expect do
          AppRevisionsListMessage.from_params({
                                                versions: [],
                                                page: 1,
                                                per_page: 5,
                                                order_by: 'created_at'
                                              })
        end.not_to raise_error
      end

      it 'accepts an empty set' do
        message = AppRevisionsListMessage.from_params({})
        expect(message).to be_valid
      end

      describe 'validations' do
        it 'validates versions is an array' do
          message = AppRevisionsListMessage.from_params(versions: 'not array')
          expect(message).not_to be_valid
          expect(message.errors[:versions].length).to eq 1
        end
      end
    end
  end
end
