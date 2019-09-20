require 'spec_helper'
require 'cloud_controller/label_selector/label_selector_parser.rb'

module VCAP::CloudController
  RSpec.describe LabelSelectorParser do
    subject(:parser) { LabelSelectorParser.new }

    describe 'parser' do
      let(:input) { '' }

      context 'empty string' do
        it 'complains' do
          result = parser.parse(input)
          expect(result).to be_falsey
          expect(parser.errors.size).to be(1)
          expect(parser.errors).to match_array('empty label selector not allowed')
          expect(parser.requirements).to be_empty
        end
      end

      context 'simple key-test' do
        it 'complains about errors' do
          [
            ['<<*>>'],
            ['<<*>>abc'],
            ['abc<<*>>'],
            ['abc<<*>>=def'],
            ['abc in (fish  ,<<?>>'],
          ].each_with_index do |augmented_input, index|
            augmented_input = augmented_input[0]
            input = augmented_input.sub('<<', '').sub('>>', '')
            result = parser.parse(input)
            expect(result).to be_falsey
            expect(parser.errors.size).to be(1)
            exp = %@disallowed character(s), got "#{augmented_input}"@
            expect(parser.errors[0]).to eq(exp), "Expected
[[#{exp}]], got
[[#{parser.errors[0]}]]
for input #{index}"
          end
        end
      end

      context 'state table coverage' do
        it 'complains' do
          [
            ['!<<>>',                'a key'],
            ['!<<,>>',               'a key'],
            ['!<<)>>',               'a key'],
            ['<<!=>> chips', "a key or '!' not followed by '='"],
            ['!abc<<=>>',            "a ',' or end"],
            ['abc=<<,>>',            'a value'],
            ['abc!=<<,>>',           'a value'],
            ['<<=>>flapjacks=1921', "a key or '!'"],

            ['abc in<<>>',           "a '('"],
            ['abc in <<>>',          "a '('"],
            ['abc in  <<>>',         "a '('"],
            ['abc in<<)>>',          "a '('"],
            ['abc in<<,>>',          "a '('"],

            ['abc in(<<>>',          'a value'],
            ['abc in (<<>>',         'a value'],
            ['abc in (fish<<>>',     "a ',' or ')'"],
            ['abc in (fish  ,<<>>',      'a value'],
            ['abc in (fish  ,<<)>>',     'a value'],

            ['abc in (fish,beef<<>>', "a ',' or ')'"],
            ['abc in (fish,beef,<<>>', 'a value'],
            ['abc in (fish,beef),<<>>', "a key or '!'"],
            ['abc in (fish,beef),<<(>>', "a key or '!'"],

            ['abc notin<<>>',           "a '('"],
            ['abc notin <<>>',          "a '('"],
            ['abc notin  <<>>',         "a '('"],
            ['abc notin<<)>>',          "a '('"],
            ['abc notin<<,>>',          "a '('"],

            ['abc notin(<<>>',          'a value'],
            ['abc notin (<<>>',         'a value'],
            ['abc notin (fish<<>>',     "a ',' or ')'"],
            ['abc notin (fish  ,<<>>',      'a value'],
            ['abc notin (fish  ,<<)>>',     'a value'],

            ['abc notin (fish,beef<<>>', "a ',' or ')'"],
            ['abc notin (fish,beef,<<>>', 'a value'],
            ['abc notin (fish,beef),<<>>', "a key or '!'"],
            ['abc notin (fish,beef),<<(>>', "a key or '!'"],

            ['abc =<<>>',           'a value'],
            ['abc = <<>>',          'a value'],
            ['abc =  <<>>',         'a value'],
            ['abc =<<)>>',          'a value'],
            ['abc =<<,>>',          'a value'],

            ['abc =<<(>>',          'a value'],
            ['abc = <<(>>',         'a value'],
            ['abc = fish  ,<<>>',      "a key or '!'"],
            ['abc = fish  ,<<)>>',     "a key or '!'"],
            ['abc = fish,<<>>', "a key or '!'"],
            ['abc = fish<<)>>,', "a ',' or end"],
            ['abc = fish <<(>>,', "a ',' or end"],
            ['abc = fish<<)>>,', "a ',' or end"],
            ['abc = fish <<flakes>>', "a ',' or end"],

            ['abc ==<<>>',           'a value'],
            ['abc == <<>>',          'a value'],
            ['abc ==  <<>>',         'a value'],
            ['abc ==<<)>>',          'a value'],
            ['abc ==<<,>>',          'a value'],

            ['abc ==<<(>>',          'a value'],
            ['abc == <<(>>',         'a value'],
            ['abc == fish  ,<<>>',      "a key or '!'"],
            ['abc == fish  ,<<)>>',     "a key or '!'"],
            ['abc == fish,<<>>', "a key or '!'"],
            ['abc == fish<<)>>,', "a ',' or end"],
            ['abc == fish <<(>>,', "a ',' or end"],
            ['abc == fish<<)>>,', "a ',' or end"],
            ['abc == fish <<flakes>>', "a ',' or end"],

            ['abc !=<<>>',           'a value'],
            ['abc != <<>>',          'a value'],
            ['abc !=  <<>>',         'a value'],
            ['abc !=<<)>>',          'a value'],
            ['abc !=<<,>>',          'a value'],

            ['abc !=<<(>>',          'a value'],
            ['abc != <<(>>',         'a value'],
            ['abc != fish  ,<<>>',      "a key or '!'"],
            ['abc != fish  ,<<)>>',     "a key or '!'"],
            ['abc != fish,<<>>', "a key or '!'"],
            ['abc != fish<<)>>,', "a ',' or end"],
            ['abc != fish <<(>>,', "a ',' or end"],
            ['abc != fish<<)>>,', "a ',' or end"],
            ['abc != fish <<flakes>>', "a ',' or end"],

            ['fish<<)>>,', "a ',', operator, or end"],
            ['fish <<(>>,', "a ',', operator, or end"],
            ['fish<<)>>,', "a ',', operator, or end"],
            ['fish <<flakes>>', "a ',', operator, or end"],

          ].each_with_index do |pair, index|
            augmented_input, reduced_expected_message = pair
            input = augmented_input.sub('<<', '').sub('>>', '')
            expected_message = %@expecting #{reduced_expected_message}, got "#{augmented_input}"@
            result = parser.parse(input)
            expect(result).to be_falsey
            expect(parser.errors.size).to be(1)
            expect(parser.errors[0]).to eq(expected_message), "Expected
[[#{expected_message}]], got
[[#{parser.errors[0]}]]
for input #{index} ('#{augmented_input}' => '#{input}')"
          end
        end
      end

      context 'state table coverage' do
        it 'complains' do
          [
            ['fish <<flakes>>', "a ',', operator, or end"],

          ].each_with_index do |pair, index|
            augmented_input, reduced_expected_message = pair
            input = augmented_input.sub('<<', '').sub('>>', '')
            expected_message = %@expecting #{reduced_expected_message}, got "#{augmented_input}"@
            result = parser.parse(input)
            expect(result).to be_falsey
            expect(parser.errors.size).to be(1)
            expect(parser.errors[0]).to eq(expected_message), "Expected
[[#{expected_message}]], got
[[#{parser.errors[0]}]]
for input #{index} ('#{augmented_input}' => '#{input}')"
          end
        end
      end
    end
  end
end
