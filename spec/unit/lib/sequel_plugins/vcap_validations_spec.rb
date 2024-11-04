require 'spec_helper'

RSpec.describe 'Sequel::Plugins::VcapValidations' do
  before do
    @c = Class.new(Sequel::Model) do
      attr_accessor :val

      def self.define_validations(&)
        define_method(:validate, &)
      end
    end
    @c.plugin :vcap_validations
    @m = @c.new
  end

  describe 'validates_url' do
    before do
      @c.define_validations { validates_url(:val) }
    end

    it 'allows a http url' do
      @m.val = 'http://foo_bar.com/bla'
      expect(@m).to be_valid
    end

    it 'allows a https url' do
      @m.val = 'https://foo_bar.com/bla'
      expect(@m).to be_valid
    end

    it 'does not allow an invalid url' do
      @m.val = 'bad url'
      expect(@m).not_to be_valid
    end

    it 'does not allow a file url' do
      @m.val = 'file://bla'
      expect(@m).not_to be_valid
    end

    it 'allows a nil url' do
      @m.val = nil
      expect(@m).to be_valid
    end

    it 'does not allow an empty url' do
      @m.val = ''
      expect(@m).not_to be_valid
    end

    it 'does not allow a url with only spaces' do
      @m.val = ' '
      expect(@m).not_to be_valid
    end

    context 'with a given error message' do
      before { @c.define_validations { validates_url(:val, message: 'must be a valid url') } }

      it 'uses that message for the validation error' do
        @m.val = ''
        @m.valid?
        expect(@m.errors.on(:val)).to eql(['must be a valid url'])
      end
    end
  end
end
