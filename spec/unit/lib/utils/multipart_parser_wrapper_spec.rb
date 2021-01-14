require 'spec_helper'

RSpec.describe VCAP::MultipartParserWrapper do
  subject(:parser) { VCAP::MultipartParserWrapper.new(body: body, boundary: boundary) }
  describe '#next_part' do
    let(:body) do
      [
        "--#{boundary}",
        "\r\n",
        "\r\n",
        first_part,
        "\r\n",
        "--#{boundary}",
        "\r\n",
        "\r\n",
        second_part,
        "\r\n",
        "--#{boundary}--",
      ].join
    end
    let(:boundary) { 'boundary-guid' }
    let(:first_part) { "part one\r\n data" }
    let(:second_part) { 'part two data' }

    it 'can return the first part' do
      expect(parser.next_part).to eq("part one\r\n data")
    end

    it 'can read more than one part' do
      expect(parser.next_part).to eq("part one\r\n data")
      expect(parser.next_part).to eq('part two data')
    end

    context 'when there are no parts left' do
      it 'returns nil' do
        expect(parser.next_part).to eq("part one\r\n data")
        expect(parser.next_part).to eq('part two data')
        expect(parser.next_part).to be_nil
      end
    end

    context 'when there body contains no parts' do
      let(:body) { "\r\n--#{boundary}--\r\n" }
      it 'returns nil' do
        expect(parser.next_part).to be_nil
      end
    end

    context 'when the body is empty' do
      let(:body) { '' }

      it 'returns nil' do
        expect(parser.next_part).to be_nil
      end
    end

    context 'when the body is not a valid multipart response' do
      let(:body) { 'potato' }

      it 'returns nil' do
        expect(parser.next_part).to be_nil
      end
    end
  end
end
