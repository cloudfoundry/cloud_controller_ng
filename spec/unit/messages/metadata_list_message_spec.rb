require 'spec_helper'
require 'messages/metadata_list_message'

module VCAP::CloudController
  RSpec.describe MetadataListMessage do
    let(:fake_class) do
      Class.new(MetadataListMessage) do
        register_allowed_keys []
      end
    end
    let(:params) do { label_selector: label_selector } end
    let(:label_selector) { 'need something here' }

    subject do
      fake_class.from_params(params, [])
    end

    context 'when given a valid label_selector' do
      let(:label_selector) { '!fruit,env=prod,animal in (dog,horse)' }

      it 'is valid' do
        expect(subject).to be_valid
      end

      it 'can return label_selector' do
        expect(subject.label_selector).to eq('!fruit,env=prod,animal in (dog,horse)')
      end
    end

    context 'when given an invalid label_selector' do
      let(:label_selector) { '' }

      it 'is invalid' do
        expect(subject).to_not be_valid
        expect(subject.errors[:base]).to include('empty label selector not allowed')
      end
    end

    describe 'label_selector parsing' do
      context 'invalid operators' do
        context 'inn' do
          let(:label_selector) { 'foo inn (bar,baz)' }

          it 'parses incorrect "in" operations as empty requirements' do
            expect(subject.requirements.size).to be(0)
            expect(subject).to_not be_valid
            expect(subject.errors.size).to be(1)
            expect(subject.errors.full_messages).to contain_exactly(%q@expecting a ',', operator, or end, got "foo <<inn>> (bar,baz)"@)
          end
        end

        context 'notinn' do
          let(:label_selector) { 'foo notinn (bar,baz)' }

          it 'parses incorrect "notin" operations as empty requirements' do
            expect(subject.requirements.size).to be(0)
            expect(subject).to_not be_valid
            expect(subject.errors.size).to be(1)
            expect(subject.errors.full_messages).to contain_exactly(%q@expecting a ',', operator, or end, got "foo <<notinn>> (bar,baz)"@)
          end
        end
      end
    end

    context 'equal on sets' do
      let(:label_selector) { 'foo == (bar,baz)' }

      it 'parses incorrect set operations as empty requirements' do
        expect(subject.requirements.size).to be(0)
        expect(subject).to_not be_valid
        expect(subject.errors.size).to be(1)
        expect(subject.errors.full_messages).to contain_exactly('expecting a value, got "foo == <<(>>bar,baz)"')
      end
    end

    context 'narp operator' do
      let(:label_selector) { 'foo notin (bar,baz),foo narp doggie,bar inn (bat)' }

      it 'parses multiple incorrect operations as empty requirementss' do
        expect(subject.requirements.size).to be(0)
        expect(subject).to_not be_valid
        expect(subject.errors.size).to be(1)
        expect(subject.errors.full_messages).to contain_exactly(%q@expecting a ',', operator, or end, got "foo notin (bar,baz),foo <<narp>> doggie,bar inn (bat)"@)
      end
    end

    context 'set operations' do
      context 'in' do
        let(:label_selector) { 'example.com/foo in (bar,baz)' }

        it 'parses correct in operation' do
          expect(subject).to be_valid
          expect(subject.requirements.size).to be(1)
          expect(subject.requirements.first.key).to eq('example.com/foo')
          expect(subject.requirements.first.operator).to eq(:in)
          expect(subject.requirements.first.values).to contain_exactly('bar', 'baz')
        end
      end

      context 'notin' do
        let(:label_selector) { 'example.com/foo notin (bar,baz)' }

        it 'parses correct notin operation' do
          expect(subject).to be_valid
          expect(subject.requirements.size).to be(1)
          expect(subject.requirements.first.key).to eq('example.com/foo')
          expect(subject.requirements.first.operator).to eq(:notin)
          expect(subject.requirements.first.values).to contain_exactly('bar', 'baz')
        end
      end
    end

    context 'equality operation' do
      context 'equals' do
        let(:label_selector) { 'example.com/foo=bar' }

        it 'parses correct = operation' do
          expect(subject).to be_valid
          expect(subject.requirements.size).to be(1)
          expect(subject.requirements.first.key).to eq('example.com/foo')
          expect(subject.requirements.first.operator).to eq(:equal)
          expect(subject.requirements.first.values).to contain_exactly('bar')
        end
      end

      context 'double equals' do
        let(:label_selector) { 'example.com/foo==bar' }

        it 'parses correct == operation' do
          expect(subject).to be_valid
          expect(subject.requirements.size).to be(1)
          expect(subject.requirements.first.key).to eq('example.com/foo')
          expect(subject.requirements.first.operator).to eq(:equal)
          expect(subject.requirements.first.values).to contain_exactly('bar')
        end
      end

      context 'not equals' do
        let(:label_selector) { 'example.com/foo!=bar' }

        it 'parses correct != operation' do
          expect(subject).to be_valid
          expect(subject.requirements.size).to be(1)
          expect(subject.requirements.first.key).to eq('example.com/foo')
          expect(subject.requirements.first.operator).to eq(:not_equal)
          expect(subject.requirements.first.values).to contain_exactly('bar')
        end
      end
    end

    context 'existence operations' do
      let(:label_selector) { 'example.com/foo' }

      it 'parses correct existence operation' do
        expect(subject).to be_valid
        expect(subject.requirements.size).to be(1)
        expect(subject.requirements.first.key).to eq('example.com/foo')
        expect(subject.requirements.first.operator).to eq(:exists)
        expect(subject.requirements.first.values).to be_empty
      end
    end

    context 'non-existence operations' do
      let(:label_selector) { '!example.com/foo' }

      it 'parses correct non-existence operation' do
        expect(subject).to be_valid
        expect(subject.requirements.size).to be(1)
        expect(subject.requirements.first.key).to eq('example.com/foo')
        expect(subject.requirements.first.operator).to eq(:not_exists)
        expect(subject.requirements.first.values).to be_empty
      end
    end

    context 'multiple operations' do
      let(:label_selector) { 'example.com/foo,bar!=baz,spork in (fork,spoon)' }
      it 'parses multiple operations' do
        expect(subject).to be_valid
        expect(subject.requirements.size).to be(3)

        expect(subject.requirements.first.key).to eq('example.com/foo')
        expect(subject.requirements.first.operator).to eq(:exists)
        expect(subject.requirements.first.values).to be_empty

        expect(subject.requirements.second.key).to eq('bar')
        expect(subject.requirements.second.operator).to eq(:not_equal)
        expect(subject.requirements.second.values).to contain_exactly('baz')

        expect(subject.requirements.third.key).to eq('spork')
        expect(subject.requirements.third.operator).to eq(:in)
        expect(subject.requirements.third.values).to contain_exactly('fork', 'spoon')
      end
    end
  end
end
