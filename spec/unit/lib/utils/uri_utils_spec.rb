require 'utils/uri_utils'

RSpec.describe UriUtils do
  describe '.is_uri?' do
    it 'is false if the object is not a string' do
      expect(UriUtils.is_uri?(1)).to be false
      expect(UriUtils.is_uri?({})).to be false
      expect(UriUtils.is_uri?([])).to be false
      expect(UriUtils.is_uri?(nil)).to be false
      expect(UriUtils.is_uri?(-> {})).to be false
      expect(UriUtils.is_uri?(:'www.example.com/path/to/thing')).to be false
      expect(UriUtils.is_uri?(1.to_c)).to be false
    end

    context 'when the object is a string' do
      it 'is false if it is not a uri' do
        expect(UriUtils.is_uri?('this is a sentence not a uri')).to be false
      end

      it 'is false if it passes the regex but is still not a uri' do
        expect(UriUtils.is_uri?('git://user@example.com:repo')).to be false
      end

      it 'is true if it is a uri' do
        expect(UriUtils.is_uri?('http://www.example.com/foobar?baz=bar')).to be true
      end
    end
  end

  describe '.is_buildpack_uri?' do
    it 'is false if the object is not a string' do
      expect(UriUtils.is_buildpack_uri?(1)).to be false
      expect(UriUtils.is_buildpack_uri?({})).to be false
      expect(UriUtils.is_buildpack_uri?([])).to be false
      expect(UriUtils.is_buildpack_uri?(nil)).to be false
      expect(UriUtils.is_buildpack_uri?(-> {})).to be false
      expect(UriUtils.is_buildpack_uri?(:'www.example.com/path/to/thing')).to be false
      expect(UriUtils.is_buildpack_uri?(1.to_c)).to be false
    end

    it 'is true if it is a git url' do
      expect(UriUtils.is_buildpack_uri?('git://user@example.com:repo.git')).to be true
    end

    it 'is true if it is an ssh git url' do
      expect(UriUtils.is_buildpack_uri?('ssh://git@example.com:repo.git')).to be true
    end

    it 'is true if it is a uri' do
      expect(UriUtils.is_buildpack_uri?('http://www.example.com/foobar?baz=bar')).to be true
    end
  end

  describe '.is_uri_path?' do
    it 'is false if the object is not a string' do
      expect(UriUtils.is_uri_path?(1)).to be false
      expect(UriUtils.is_uri_path?({})).to be false
      expect(UriUtils.is_uri_path?([])).to be false
      expect(UriUtils.is_uri_path?(nil)).to be false
      expect(UriUtils.is_uri_path?(-> {})).to be false
      expect(UriUtils.is_uri_path?(:'/path/to/thing')).to be false
      expect(UriUtils.is_uri_path?(1.to_c)).to be false
    end

    context 'when the object is a string' do
      it 'is false if it is a relative path' do
        expect(UriUtils.is_uri_path?('path/to/thing')).to be false
      end

      it 'is false if it starts with "//"' do
        expect(UriUtils.is_uri_path?('//path/to/thing')).to be false
      end

      it 'is true with the root path' do
        expect(UriUtils.is_uri_path?('/')).to be true
      end

      it 'is false for empty strings' do
        expect(UriUtils.is_uri_path?('')).to be false
      end

      it 'is true for valid absolute paths' do
        expect(UriUtils.is_uri_path?('/path')).to be true
        expect(UriUtils.is_uri_path?('/path/to/thing')).to be true
      end
    end
  end
end
