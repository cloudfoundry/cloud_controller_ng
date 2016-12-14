require 'ext/object_ext'

RSpec.describe Object do
  describe 'is_uri?' do
    it 'is false if the object is not a string' do
      expect(1.is_uri?).to be false
      expect({}.is_uri?).to be false
      expect([].is_uri?).to be false
      expect(nil.is_uri?).to be false
      expect(-> {}.is_uri?).to be false
      expect(:'www.example.com/path/to/thing'.is_uri?).to be false
      expect(1.to_c.is_uri?).to be false
    end

    context 'when the object is a string' do
      it 'is false if it is not a uri' do
        expect('this is a sentence not a uri'.is_uri?).to be false
      end

      it 'is false if it passes the regex but is still not a uri' do
        expect('git://user@example.com:repo'.is_uri?).to be false
      end

      it 'is true if it is a uri' do
        expect('http://www.example.com/foobar?baz=bar'.is_uri?).to be true
      end
    end
  end

  describe 'is_uri_path?' do
    it 'is false if the object is not a string' do
      expect(1.is_uri_path?).to be false
      expect({}.is_uri_path?).to be false
      expect([].is_uri_path?).to be false
      expect(nil.is_uri_path?).to be false
      expect(-> {}.is_uri_path?).to be false
      expect(:'/path/to/thing'.is_uri_path?).to be false
      expect(1.to_c.is_uri_path?).to be false
    end

    context 'when the object is a string' do
      it 'is false if it is a relative path' do
        expect('path/to/thing'.is_uri_path?).to be false
      end

      it 'is false if it starts with "//"' do
        expect('//path/to/thing'.is_uri_path?).to be false
      end

      it 'is true with the root path' do
        expect('/'.is_uri_path?).to be true
      end

      it 'is false for empty strings' do
        expect(''.is_uri_path?).to be false
      end

      it 'is true for valid absolute paths' do
        expect('/path'.is_uri_path?).to be true
        expect('/path/to/thing'.is_uri_path?).to be true
      end
    end
  end
end
