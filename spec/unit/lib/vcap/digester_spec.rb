require 'spec_helper'
require 'vcap/digester'

RSpec.describe Digester do
  let(:tempfile) do
    Tempfile.new('coolfile').tap do |f|
      f.write('I am a teapot!')
      f.close
    end
  end
  let(:sha) { '5d10be7baa938c793756e79819866561abaae5b3' }

  subject(:digester) { Digester.new }

  describe '#digest' do
    it 'digests the given bits' do
      expect(digester.digest('I am a teapot!')).to eq(sha)
    end
  end

  describe '#digest_path' do
    it 'digests the file at the given path' do
      expect(digester.digest_path(tempfile.path)).to eq(sha)
    end
  end

  describe '#digest_file' do
    it 'digests the given file' do
      expect(digester.digest_file(tempfile)).to eq(sha)
    end
  end

  describe 'changing the algorithm' do
    subject(:digester) { Digester.new(algorithm: Digest::MD5) }
    let(:md5) { '9f3f3f57770f25cb8faa685d7336aa4c' }

    it 'uses the given algorithm' do
      expect(digester.digest('I am a teapot!')).to eq(md5)
    end
  end

  describe 'changing the digest type' do
    subject(:digester) { Digester.new(type: :base64digest) }
    let(:sha) { 'XRC+e6qTjHk3VueYGYZlYauq5bM=' }

    it 'uses the given digest type' do
      expect(digester.digest('I am a teapot!')).to eq(sha)
    end
  end
end
