require 'membrane'
require 'ext/validation_error_message_overrides'
require 'vcap/rest_api/message'

describe ::Membrane::Schemas::Regexp::MatchValidator do
  describe '#fail' do
    let(:object) { 'some-string' }

    subject { described_class.new(regexp, object) }

    context 'with a normal ruby regexp' do
      let(:regexp) { /foo/ }

      it 'generates the default message' do
        expected_emsg = "Value #{object} doesn't match regexp #{regexp.inspect}"
        expect { subject.fail!(regexp, object) }.to raise_error(::Membrane::SchemaValidationError, /#{expected_emsg}/)
      end
    end

    context 'with a custom readable_regexp for a URL' do
      let(:regexp) { ::VCAP::RestAPI::Message::URL }

      it 'generates a readable message' do
        expected_emsg = 'must be a valid URL'
        expect { subject.fail!(regexp, object) }.to raise_error(::Membrane::SchemaValidationError, /#{expected_emsg}/)
      end
    end

    context 'with a custom readable_regexp for an HTTPS URL' do
      let(:regexp) { ::VCAP::RestAPI::Message::HTTPS_URL }

      it 'generates a readable message' do
        expected_emsg = 'must be a valid HTTPS URL'
        expect { subject.fail!(regexp, object) }.to raise_error(::Membrane::SchemaValidationError, /#{expected_emsg}/)
      end
    end

    context 'with a custom readable_regexp for an email' do
      let(:regexp) { ::VCAP::RestAPI::Message::EMAIL }

      it 'generates a readable message' do
        expected_emsg = 'must be a valid email'
        expect { subject.fail!(regexp, object) }.to raise_error(::Membrane::SchemaValidationError, /#{expected_emsg}/)
      end
    end

    context 'with a custom readable_regexp for a git URL' do
      let(:regexp) { ::VCAP::RestAPI::Message::GIT_URL }

      it 'generates a readable message' do
        expected_emsg = 'must be a valid git URL'
        expect { subject.fail!(regexp, object) }.to raise_error(::Membrane::SchemaValidationError, /#{expected_emsg}/)
      end
    end
  end
end
