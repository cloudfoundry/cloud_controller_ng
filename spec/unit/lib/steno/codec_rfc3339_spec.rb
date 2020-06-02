require 'spec_helper'
require 'steno/codec_rfc3339'

RSpec.describe Steno::Codec::JsonRFC3339 do
  let(:codec) { Steno::Codec::JsonRFC3339.new }
  let(:record) { make_record(data: { 'user' => 'data' }) }

  describe '#encode_record' do
    it 'should encode records as json hashes' do
      parsed = Yajl::Parser.parse(codec.encode_record(record))
      expect(parsed.class).to eq(Hash)
    end

    it 'should encode the timestamp as a string' do
      parsed = Yajl::Parser.parse(codec.encode_record(record))
      expect(parsed['timestamp'].class).to eq(String)
    end

    it 'should escape newlines' do
      rec = make_record(message: "newline\ntest")
      expect(codec.encode_record(rec)).to match(/newline\\ntest/)
    end

    it 'should escape carriage returns' do
      rec = make_record(message: "newline\rtest")
      expect(codec.encode_record(rec)).to match(/newline\\rtest/)
    end

    it 'should allow messages with valid encodings to pass through untouched' do
      msg = "HI\u2600"
      rec = make_record(message: msg)
      expect(codec.encode_record(rec)).to match(/#{msg}/)
    end

    it 'should treat messages with invalid encodings as binary data' do
      msg = "HI\u2026".force_encoding('US-ASCII')
      rec = make_record(message: msg)
      expect(codec.encode_record(rec)).to match(/HI\\\\xe2\\\\x80\\\\xa6/)
    end

    it 'should encode timestamps as UTC-formatted strings' do
      allow(record).to receive(:timestamp).and_return 1396473763 # 2014-04-02 22:22:43 +01:00
      parsed = Yajl::Parser.parse(codec.encode_record(record))

      expect(parsed['timestamp'].class).to eq(String)
      expect(parsed['timestamp']).to eq('2014-04-02T21:22:43.000000000Z')
    end
  end

  def make_record(opts={})
    Steno::Record.new(opts[:source] || 'my_source',
      opts[:level]   || :debug,
      opts[:message] || 'test message',
      nil,
      opts[:data] || {})
  end
end
