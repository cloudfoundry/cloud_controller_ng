require 'spec_helper'
require 'messages/packages_list_message'

module VCAP::CloudController
  describe PackagesListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'page'     => 1,
          'per_page' => 5,
        }
      end

      it 'returns the correct PackagesListMessage' do
        message = PackagesListMessage.from_params(params)

        expect(message).to be_a(PackagesListMessage)
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
      end

      it 'converts requested keys to symbols' do
        message = PackagesListMessage.from_params(params)

        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        expect {
          PackagesListMessage.new({
              page:               1,
              per_page:           5,
            })
        }.not_to raise_error
      end

      it 'accepts an empty set' do
        message = PackagesListMessage.new
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = PackagesListMessage.new({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown query parameter(s): 'foobar'")
      end

      describe 'validations' do
        describe 'page' do
          it 'validates it is a number' do
            message = PackagesListMessage.new page: 'not number'
            expect(message).to be_invalid
            expect(message.errors[:page].length).to eq 1
          end

          it 'is invalid if page is 0' do
            message = PackagesListMessage.new page: 0
            expect(message).to be_invalid
            expect(message.errors[:page].length).to eq 1
          end

          it 'is invalid if page is negative' do
            message = PackagesListMessage.new page: -1
            expect(message).to be_invalid
            expect(message.errors[:page].length).to eq 1
          end

          it 'is invalid if page is not an integer' do
            message = PackagesListMessage.new page: 1.1
            expect(message).to be_invalid
            expect(message.errors[:page].length).to eq 1
          end
        end

        describe 'per_page' do
          it 'validates it is a number' do
            message = PackagesListMessage.new per_page: 'not number'
            expect(message).to be_invalid
            expect(message.errors[:per_page].length).to eq 1
          end

          it 'is invalid if per_page is 0' do
            message = PackagesListMessage.new per_page: 0
            expect(message).to be_invalid
            expect(message.errors[:per_page].length).to eq 1
          end

          it 'is invalid if per_page is negative' do
            message = PackagesListMessage.new per_page: -1
            expect(message).to be_invalid
            expect(message.errors[:per_page].length).to eq 1
          end

          it 'is invalid if per_page is not an integer' do
            message = PackagesListMessage.new per_page: 1.1
            expect(message).to be_invalid
            expect(message.errors[:per_page].length).to eq 1
          end
        end
      end
    end
  end
end
