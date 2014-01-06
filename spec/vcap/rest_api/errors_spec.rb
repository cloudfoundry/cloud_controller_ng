require "spec_helper"

module VCAP::CloudController::Errors
  describe Error do
    describe '#initialize' do
      context 'when the message format contains %s' do
        let(:response_code) { 200 }
        let(:error_code) { 999999 }
        let(:format) { "Your error is: %s" }
        context 'when the string args are all strings' do
          let(:arg0) { 'You messed up' }
          it 'inserts the strings into the message normally' do
            error = described_class.new(response_code, error_code, format, arg0)
            error.message.should == 'Your error is: You messed up'
          end
        end

        context 'when the string args contains an array of strings' do
          let(:arg0) { ['invalid arguments', 'too many arguments'] }
          it 'inserts the items in the array into the string, separated by commas' do
            error = described_class.new(response_code, error_code, format, arg0)
            error.message.should == 'Your error is: invalid arguments, too many arguments'
          end
        end
      end
    end
  end
end
