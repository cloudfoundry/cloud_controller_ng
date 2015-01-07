require 'spec_helper'
require 'ext/file'

describe File do
  describe '#hexdigest' do
    it 'make a sha for the file' do
      expect(File.new(__FILE__).hexdigest).to match /.+{12}/
    end
  end
end
