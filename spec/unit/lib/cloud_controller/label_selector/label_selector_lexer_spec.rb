require 'spec_helper'
require 'cloud_controller/label_selector/label_selector_lexer.rb'

module VCAP::CloudController
  RSpec.describe LabelSelectorLexer do
    subject(:target_state) { LabelSelectorLexer.new }

    describe 'tokens' do
      context 'invalid label_selector' do
        let(:input) { '* pickles in  (foo)' }

        context 'the revision exists' do
          it 'contains an error token' do
            tokens = subject.scan(input)
            expect(tokens[0]).to eq([:error, '*', 0])
            expect(tokens.find { |tok| tok[0] == :error }).not_to be_nil
            expect(tokens.size).to eq(9)
            expect(tokens[1]).to eq([:space, ' ', 1])
            expect(tokens[2]).to eq([:word, 'pickles', 2])

            expect(tokens.reject { |tok| tok[0] == :space }.size).to eq(6)
          end
        end
      end
    end
  end
end
