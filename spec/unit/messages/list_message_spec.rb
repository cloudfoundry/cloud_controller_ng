require 'spec_helper'
require 'messages/list_message'

class VCAP::CloudController::ListMessage
  def allowed_keys
    # redefining here so NotImplementedError isn't raised
  end
end

module VCAP::CloudController
  RSpec.describe ListMessage do
    describe 'page' do
      it 'is invalid if page is a string' do
        message = ListMessage.new page: 'a string'
        expect(message).to be_invalid
        expect(message.errors[:page]).to include('must be a positive integer')
      end

      it 'is invalid if page is 0' do
        message = ListMessage.new page: 0
        expect(message).to be_invalid
        expect(message.errors[:page]).to include('must be a positive integer')
      end

      it 'is invalid if page is negative' do
        message = ListMessage.new page: -1
        expect(message).to be_invalid
        expect(message.errors[:page]).to include('must be a positive integer')
      end

      it 'is valid if page is nil' do
        message = ListMessage.new
        expect(message).to be_valid
      end
    end

    describe 'per_page' do
      it 'is invalid if per_page is a string' do
        message = ListMessage.new per_page: 'a string'
        expect(message).to be_invalid
        expect(message.errors[:per_page]).to include('must be a positive integer')
      end

      it 'is invalid if per_page is 0' do
        message = ListMessage.new per_page: 0
        expect(message).to be_invalid
        expect(message.errors[:per_page]).to include('must be a positive integer')
      end

      it 'is invalid if per_page is negative' do
        message = ListMessage.new per_page: -1
        expect(message).to be_invalid
        expect(message.errors[:per_page]).to include('must be a positive integer')
      end

      it 'is valid if per_page is nil' do
        message = ListMessage.new per_page: nil
        expect(message).to be_valid
      end

      it 'is valid if it is between 1 and 5000' do
        invalid_message = ListMessage.new per_page: 5001
        message = ListMessage.new per_page: 5000

        expect(message).to be_valid
        expect(invalid_message).to be_invalid
      end
    end

    describe 'order validations' do
      context 'when order_by is present' do
        it 'validates when order_by is `created_at`' do
          message = ListMessage.new order_by: 'created_at'
          expect(message).to be_valid
        end

        it 'validates when order_by is `+created_at`' do
          message = ListMessage.new order_by: '+created_at'
          expect(message).to be_valid
        end

        it 'validates when order_by is `-updated_at`' do
          message = ListMessage.new order_by: '-updated_at'
          expect(message).to be_valid
        end

        it 'does not validate when order_by is `something_else`' do
          message = ListMessage.new order_by: 'something_else'
          expect(message).to be_invalid
        end

        it 'does not validate when order_by is `*created_at`' do
          message = ListMessage.new order_by: '*created_at'
          expect(message).to be_invalid
        end

        it 'does not validate when order_by is `12312`' do
          message = ListMessage.new order_by: '12312'
          expect(message).to be_invalid
        end
      end

      context 'when order_by is not present' do
        it 'only validates order_by' do
          expect(ListMessage.new).to be_valid
        end
      end
    end
  end
end
