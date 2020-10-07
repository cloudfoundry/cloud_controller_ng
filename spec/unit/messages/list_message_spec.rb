require 'spec_helper'
require 'messages/list_message'

class VCAP::CloudController::ListMessage
  register_allowed_keys []
end

module VCAP::CloudController
  RSpec.describe ListMessage do
    describe 'page' do
      it 'is invalid if page is a string' do
        message = ListMessage.from_params({ page: 'a string' }, [])
        expect(message).to be_invalid
        expect(message.errors[:page]).to include('must be a positive integer')
      end

      it 'is invalid if page is 0' do
        message = ListMessage.from_params({ page: 0 }, [])
        expect(message).to be_invalid
        expect(message.errors[:page]).to include('must be a positive integer')
      end

      it 'is invalid if page is negative' do
        message = ListMessage.from_params({ page: -1 }, [])
        expect(message).to be_invalid
        expect(message.errors[:page]).to include('must be a positive integer')
      end

      it 'is valid if page is nil' do
        message = ListMessage.from_params({}, [])
        expect(message).to be_valid
      end
    end

    describe 'per_page' do
      it 'is invalid if per_page is a string' do
        message = ListMessage.from_params({ per_page: 'a string' }, [])
        expect(message).to be_invalid
        expect(message.errors[:per_page]).to include('must be a positive integer')
      end

      it 'is invalid if per_page is 0' do
        message = ListMessage.from_params({ per_page: 0 }, [])
        expect(message).to be_invalid
        expect(message.errors[:per_page]).to include('must be a positive integer')
      end

      it 'is invalid if per_page is negative' do
        message = ListMessage.from_params({ per_page: -1 }, [])
        expect(message).to be_invalid
        expect(message.errors[:per_page]).to include('must be a positive integer')
      end

      it 'is valid if per_page is nil' do
        message = ListMessage.from_params({ per_page: nil }, [])
        expect(message).to be_valid
      end

      it 'is valid if it is between 1 and 5000' do
        invalid_message = ListMessage.from_params({ per_page: 5001 }, [])
        message = ListMessage.from_params({ per_page: 5000 }, [])

        expect(message).to be_valid
        expect(invalid_message).to be_invalid
      end
    end

    describe 'order validations' do
      context 'when order_by is present' do
        it 'validates when order_by is `created_at`' do
          message = ListMessage.from_params({ order_by: 'created_at' }, [])
          expect(message).to be_valid
        end

        it 'validates when order_by is `+created_at`' do
          message = ListMessage.from_params({ order_by: '+created_at' }, [])
          expect(message).to be_valid
        end

        it 'validates when order_by is `-updated_at`' do
          message = ListMessage.from_params({ order_by: '-updated_at' }, [])
          expect(message).to be_valid
        end

        it 'does not validate when order_by is `something_else`' do
          message = ListMessage.from_params({ order_by: 'something_else' }, [])
          expect(message).to be_invalid
        end

        it 'does not validate when order_by is `*created_at`' do
          message = ListMessage.from_params({ order_by: '*created_at' }, [])
          expect(message).to be_invalid
        end

        it 'does not validate when order_by is `12312`' do
          message = ListMessage.from_params({ order_by: '12312' }, [])
          expect(message).to be_invalid
        end
      end

      context 'when order_by is not present' do
        it 'only validates order_by' do
          expect(ListMessage.from_params({}, [])).to be_valid
        end
      end
    end

    describe 'label_selector parsing' do
      let(:list_message_klass) do
        Class.new(VCAP::CloudController::ListMessage) do
          register_allowed_keys [:label_selector]

          def self.from_params(params)
            super(params, [])
          end
        end
      end

      context 'invalid operators' do
        it 'parses incorrect "in" operations as nil requirement' do
          message = list_message_klass.from_params('label_selector' => 'foo inn (bar,baz)')

          expect(message.requirements).to contain_exactly(nil)
        end

        it 'parses incorrect "notin" operations as nil requirement' do
          message = list_message_klass.from_params('label_selector' => 'foo notinn (bar,baz)')

          expect(message.requirements).to contain_exactly(nil)
        end

        it 'parses incorrect set operations as nil requirement' do
          message = list_message_klass.from_params('label_selector' => 'foo == (bar,baz)')

          expect(message.requirements).to contain_exactly(nil)
        end

        it 'parses multiple incorrect operations as nil requirements' do
          message = list_message_klass.from_params('label_selector' => 'foo == (bar,baz),foo narp doggie,bar inn (bat)')

          expect(message.requirements).to contain_exactly(nil, nil, nil)
        end
      end

      context 'set operations' do
        it 'parses correct in operation' do
          message = list_message_klass.from_params('label_selector' => 'example.com/foo in (bar,baz)')

          expect(message.requirements.first.key).to eq('example.com/foo')
          expect(message.requirements.first.operator).to eq(:in)
          expect(message.requirements.first.values).to contain_exactly('bar', 'baz')
        end

        it 'parses correct notin operation' do
          message = list_message_klass.from_params('label_selector' => 'example.com/foo notin (bar,baz)')

          expect(message.requirements.first.key).to eq('example.com/foo')
          expect(message.requirements.first.operator).to eq(:notin)
          expect(message.requirements.first.values).to contain_exactly('bar', 'baz')
        end
      end

      context 'equality operation' do
        it 'parses correct = operation' do
          message = list_message_klass.from_params('label_selector' => 'example.com/foo=bar')

          expect(message.requirements.first.key).to eq('example.com/foo')
          expect(message.requirements.first.operator).to eq(:equal)
          expect(message.requirements.first.values).to contain_exactly('bar')
        end

        it 'parses correct == operation' do
          message = list_message_klass.from_params('label_selector' => 'example.com/foo==bar')

          expect(message.requirements.first.key).to eq('example.com/foo')
          expect(message.requirements.first.operator).to eq(:equal)
          expect(message.requirements.first.values).to contain_exactly('bar')
        end

        it 'parses correct != operation' do
          message = list_message_klass.from_params('label_selector' => 'example.com/foo!=bar')

          expect(message.requirements.first.key).to eq('example.com/foo')
          expect(message.requirements.first.operator).to eq(:not_equal)
          expect(message.requirements.first.values).to contain_exactly('bar')
        end
      end

      context 'existence operations' do
        it 'parses correct existence operation' do
          message = list_message_klass.from_params('label_selector' => 'example.com/foo')

          expect(message.requirements.first.key).to eq('example.com/foo')
          expect(message.requirements.first.operator).to eq(:exists)
          expect(message.requirements.first.values).to be_empty
        end

        it 'parses correct non-existence operation' do
          message = list_message_klass.from_params('label_selector' => '!example.com/foo')

          expect(message.requirements.first.key).to eq('example.com/foo')
          expect(message.requirements.first.operator).to eq(:not_exists)
          expect(message.requirements.first.values).to be_empty
        end
      end

      context 'multiple operations' do
        it 'parses multiple operations' do
          message = list_message_klass.from_params('label_selector' => 'example.com/foo,bar!=baz,spork in (fork,spoon)')

          expect(message.requirements.first.key).to eq('example.com/foo')
          expect(message.requirements.first.operator).to eq(:exists)
          expect(message.requirements.first.values).to be_empty

          expect(message.requirements.second.key).to eq('bar')
          expect(message.requirements.second.operator).to eq(:not_equal)
          expect(message.requirements.second.values).to contain_exactly('baz')

          expect(message.requirements.third.key).to eq('spork')
          expect(message.requirements.third.operator).to eq(:in)
          expect(message.requirements.third.values).to contain_exactly('fork', 'spoon')
        end
      end

      context 'input form' do
        it 'handles ruby strings' do
          message = list_message_klass.from_params('label_selector' => 'example.com/foo==bar')
          expect(message.requirements.first.key).to eq('example.com/foo')
        end

        it 'handles ruby symbols' do
          message = list_message_klass.from_params(label_selector: 'example.com/foo==bar')
          expect(message.requirements.first.key).to eq('example.com/foo')
        end
      end
    end

    describe 'timestamp validations' do
      context 'validates the created_ats filter' do
        it 'delegates to the TimestampValidator' do
          message = ListMessage.from_params({ 'created_ats' => 47 }, [])
          expect(message).not_to be_valid
          expect(message.errors[:created_ats]).to include("has an invalid timestamp format. Timestamps should be formatted as 'YYYY-MM-DDThh:mm:ssZ'")
        end
        it 'validates guids are in array format' do
          message = ListMessage.from_params({ guids: 47 }, [])
          expect(message).not_to be_valid
          expect(message.errors[:guids]).to include('must be an array')
        end
      end

      context 'validates the updated_ats filter' do
        it 'delegates to the TimestampValidator' do
          message = ListMessage.from_params({ 'updated_ats' => { gte: '2020-06-30T23:49:04Z' } }, [])
          expect(message).to be_valid
        end
      end

      context 'validates the updated_ats filter' do
        it 'delegates to the TimestampValidator' do
          message = ListMessage.from_params({ 'updated_ats' => 47 }, [])
          expect(message).not_to be_valid
          expect(message.errors[:updated_ats]).to include("has an invalid timestamp format. Timestamps should be formatted as 'YYYY-MM-DDThh:mm:ssZ'")
        end
      end
    end

    context 'validates the guids filter' do
      it 'validates guids are in array format' do
        message = ListMessage.from_params({ 'guids' => { guid: 47 } }, [])
        expect(message).not_to be_valid
        expect(message.errors[:guids]).to include('must be an array')
      end
    end
  end
end
