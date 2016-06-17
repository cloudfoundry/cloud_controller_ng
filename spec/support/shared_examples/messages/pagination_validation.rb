RSpec.shared_examples_for 'a page validator' do
  describe 'page' do
    it 'is invalid if page is a string' do
      message = described_class.new page: 'a string'
      expect(message).to be_invalid
      expect(message.errors[:page]).to include('must be a positive integer')
    end

    it 'is invalid if page is 0' do
      message = described_class.new page: 0
      expect(message).to be_invalid
      expect(message.errors[:page]).to include('must be a positive integer')
    end

    it 'is invalid if page is negative' do
      message = described_class.new page: -1
      expect(message).to be_invalid
      expect(message.errors[:page]).to include('must be a positive integer')
    end
  end
end

RSpec.shared_examples_for 'a per_page validator' do
  describe 'per_page' do
    it 'is invalid if per_page is a string' do
      message = described_class.new per_page: 'not number'
      expect(message).to be_invalid
      expect(message.errors[:per_page]).to include('must be a positive integer')
    end

    it 'is invalid if per_page is 0' do
      message = described_class.new per_page: 0
      expect(message).to be_invalid
      expect(message.errors[:per_page]).to include('must be a positive integer')
    end

    it 'is invalid if per_page is negative' do
      message = described_class.new per_page: -1
      expect(message).to be_invalid
      expect(message.errors[:per_page]).to include('must be a positive integer')
    end
  end
end

RSpec.shared_examples_for 'an order_by validator' do
  describe 'order_by' do
    it 'must be one of the valid strings' do
      message1 = described_class.new order_by: 'created_at'
      message2 = described_class.new order_by: 'updated_at'
      invalid_message = described_class.new order_by: 'wee'

      expect(message1).to be_valid
      expect(message2).to be_valid
      expect(invalid_message).to_not be_valid
      expect(invalid_message.errors[:order_by]).to include("can only be 'created_at' or 'updated_at'")
    end
  end
end

RSpec.shared_examples_for 'an order_direction validator' do
  describe 'order_direction' do
    it 'must be one of the valid strings' do
      message1 = described_class.new order_by: 'created_at', order_direction: '+'
      message2 = described_class.new order_by: 'created_at', order_direction: '-'
      invalid_message = described_class.new order_direction: 'weee'

      expect(message1).to be_valid
      expect(message2).to be_valid
      expect(invalid_message).to_not be_valid
      expect(invalid_message.errors[:order_direction]).to include("can only be '+' or '-'")
    end
  end
end
