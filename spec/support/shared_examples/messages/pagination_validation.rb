shared_examples_for 'a page validator' do
  describe 'page' do
    it 'is invalid if page is a string' do
      message = described_class.new page: 'a string'
      expect(message).to be_invalid
      expect(message.errors[:page]).to include('is not a number')
    end

    it 'is invalid if page is 0' do
      message = described_class.new page: 0
      expect(message).to be_invalid
      expect(message.errors[:page]).to include('must be greater than 0')
    end

    it 'is invalid if page is negative' do
      message = described_class.new page: -1
      expect(message).to be_invalid
      expect(message.errors[:page]).to include('must be greater than 0')
    end

    it 'is invalid if page is not an integer' do
      message = described_class.new page: 1.1
      expect(message).to be_invalid
      expect(message.errors[:page]).to include('must be an integer')
    end
  end
end

shared_examples_for 'a per_page validator' do
  describe 'per_page' do
    it 'is invalid if per_page is a string' do
      message = described_class.new per_page: 'not number'
      expect(message).to be_invalid
      expect(message.errors[:per_page]).to include('is not a number')
    end

    it 'is invalid if per_page is 0' do
      message = described_class.new per_page: 0
      expect(message).to be_invalid
      expect(message.errors[:per_page]).to include('must be greater than 0')
    end

    it 'is invalid if per_page is negative' do
      message = described_class.new per_page: -1
      expect(message).to be_invalid
      expect(message.errors[:per_page]).to include('must be greater than 0')
    end

    it 'is invalid if per_page is not an integer' do
      message = described_class.new per_page: 1.1
      expect(message).to be_invalid
      expect(message.errors[:per_page]).to include('must be an integer')
    end
  end
end
