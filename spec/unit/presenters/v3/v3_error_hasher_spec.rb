require 'spec_helper'

RSpec.describe V3ErrorHasher do
  subject(:error_hasher) { V3ErrorHasher.new(error) }

  let(:unknown_error) do
    error = RuntimeError.new('fake message')
    error.set_backtrace('fake backtrace')
    error
  end

  let(:services_error) do
    error = StructuredError.new('fake message', 'fake source')
    error.set_backtrace('fake backtrace')
    error
  end

  let(:api_error) do
    error = CloudController::Errors::ApiError.new_from_details('DomainInvalid', 'notadomain')
    error.set_backtrace('fake backtrace')
    error
  end

  let(:to_h_error) do
    error = RuntimeError.new('fake message')
    error.set_backtrace('fake backtrace')
    allow(error).to receive(:to_h).and_return('arbritratry key' => 'arbritratry value', 'code' => 67890, 'source' => 'fake source')
    error
  end

  describe '#unsanitized_hash' do
    subject(:unsanitized_hash) do
      error_hasher.unsanitized_hash
    end

    context 'when the error knows how to convert itself into a hash' do
      let(:error) { to_h_error }

      it 'lets the error do the conversion' do
        expect(unsanitized_hash).to eq('errors' => [{
          'code'           => 10001,
          'title'          => 'UnknownError',
          'detail'         => 'An unknown error occurred.',
          'test_mode_info' => {
            'detail'          => 'fake message',
            'code'            => 67890,
            'title'           => 'CF-RuntimeError',
            'source'          => 'fake source',
            'arbritratry key' => 'arbritratry value',
            'backtrace'       => ['fake backtrace'],
          }
        }])
      end
    end

    context 'with an ApiError' do
      let(:error) { api_error }

      it 'uses a standard convention by default' do
        expect(unsanitized_hash).to eq('errors' => [{
          'code'           => 130001,
          'detail'         => 'The domain is invalid: notadomain',
          'title'          => 'CF-DomainInvalid',
          'test_mode_info' => {
            'detail'    => 'The domain is invalid: notadomain',
            'title'     => 'CF-DomainInvalid',
            'backtrace' => ['fake backtrace'],
          }
        }])
      end
    end

    context 'with a services error' do
      let(:error) { services_error }

      it 'uses a standard convention by default' do
        expect(unsanitized_hash).to eq('errors' => [{
          'code'           => 10001,
          'detail'         => 'fake message',
          'title'          => 'CF-StructuredError',
          'test_mode_info' => {
            'detail'      => 'fake message',
            'description' => 'fake message',
            'title'       => 'CF-StructuredError',
            'source'      => 'fake source',
            'backtrace'   => ['fake backtrace'],
          }
        }])
      end
    end

    context 'with nil' do
      let(:error) { nil }

      it 'returns a default hash' do
        expect(unsanitized_hash).to eq('errors' => [{
          'title'  => 'UnknownError',
          'detail' => 'An unknown error occurred.',
          'code'   => 10001,
        }])
      end
    end

    context 'with an unknown error' do
      let(:error) { unknown_error }

      it 'uses a standard convention by default' do
        expect(unsanitized_hash).to eq('errors' => [{
          'code'           => 10001,
          'detail'         => 'An unknown error occurred.',
          'title'          => 'UnknownError',
          'test_mode_info' => {
            'detail'    => 'fake message',
            'title'     => 'CF-RuntimeError',
            'backtrace' => ['fake backtrace'],
          }
        }])
      end
    end
  end

  describe '#sanitized_hash' do
    subject(:sanitized_hash) do
      error_hasher.sanitized_hash
    end

    context 'when the error knows how to convert itself into a hash' do
      let(:error) { to_h_error }

      it 'returns the default hash' do
        expect(sanitized_hash).to eq('errors' => [{
          'title'  => 'UnknownError',
          'detail' => 'An unknown error occurred.',
          'code'   => 10001
        }])
      end
    end

    context 'with an ApiError' do
      context 'when the error is a Errors::ApiError' do
        let(:error) { api_error }

        it 'uses a standard convention by default' do
          expect(sanitized_hash).to eq('errors' => [{
            'code'   => 130001,
            'detail' => 'The domain is invalid: notadomain',
            'title'  => 'CF-DomainInvalid'
          }])
        end
      end

      context 'when the error acts like an api error' do
        let(:error) { CloudController::Errors::NotAuthenticated.new }

        it 'uses a standard convention by default' do
          expect(sanitized_hash).to eq('errors' => [{
            'code'   => 10002,
            'detail' => 'Authentication error',
            'title'  => 'CF-NotAuthenticated'
          }])
        end
      end
    end

    context 'with a services error' do
      let(:error) { services_error }

      it 'uses a standard convention by default' do
        expect(sanitized_hash).to eq('errors' => [{
          'code'   => 10001,
          'detail' => 'fake message',
          'title'  => 'CF-StructuredError'
        }])
      end
    end

    context 'with nil' do
      let(:error) { nil }

      it 'returns a default hash' do
        expect(sanitized_hash).to eq('errors' => [{
          'title'  => 'UnknownError',
          'detail' => 'An unknown error occurred.',
          'code'   => 10001,
        }])
      end
    end

    context 'with an unknown error' do
      let(:error) { unknown_error }

      it 'uses a standard convention by default' do
        expect(sanitized_hash).to eq('errors' => [{
          'code'   => 10001,
          'detail' => 'An unknown error occurred.',
          'title'  => 'UnknownError'
        }])
      end
    end

    context 'with a services error where some arbitrary information is set' do
      let(:error) { services_error }

      before do
        allow(error).to receive(:to_h).and_return('arbitrary key' => 'arbitrary value')
      end

      it 'does not expose the extra information' do
        expect(sanitized_hash['errors'].first).not_to have_key('arbitrary key')
      end
    end
  end
end
