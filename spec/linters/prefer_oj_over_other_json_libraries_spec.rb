require 'spec_helper'
require 'rubocop'
require 'rubocop/rspec/cop_helper'
require 'rubocop/config'
require 'linters/prefer_oj_over_other_json_libraries'

RSpec.describe RuboCop::Cop::PreferOjOverOtherJsonLibraries do
  include CopHelper

  subject(:cop) { RuboCop::Cop::PreferOjOverOtherJsonLibraries.new(RuboCop::Config.new({})) }

  it 'registers an offense if MultiJson is used' do
    result = inspect_source(<<~RUBY)
      def parse_and_validate_json(body)
        MultiJson.load(body)
      rescue MultiJson::ParseError => e
        bad_request!(e.message)
      end
    RUBY

    expect(result.size).to eq(1)
    expect(result.map(&:message)).to eq(['Avoid using `MultiJson`, prefer `Oj` instead'])
  end

  it 'registers an offense if JSON is used' do
    result = inspect_source(<<~RUBY)
      def extract_documentation_url(extra)
        metadata = JSON.parse(extra)
        metadata['documentationUrl']
      rescue JSON::ParserError
        nil
      end
    RUBY

    expect(result.size).to eq(1)
    expect(result.map(&:message)).to eq(['Avoid using `JSON`, prefer `Oj` instead'])
  end

  it 'registers an offense if Yajl::Parser is used' do
    result = inspect_source(<<~RUBY)
      def decode(json)
        Yajl::Parser.parse(json)
      rescue StandardError => e
        raise ParseError.new(e.to_s)
      end
    RUBY

    expect(result.size).to eq(1)
    expect(result.map(&:message)).to eq(['Avoid using `Yajl`, prefer `Oj` instead'])
  end

  it 'registers an offense if Yajl::Encoder is used' do
    result = inspect_source(<<~RUBY)
      def encode
        Yajl::Encoder.encode(@msg)
      end
    RUBY

    expect(result.size).to eq(1)
    expect(result.map(&:message)).to eq(['Avoid using `Yajl`, prefer `Oj` instead'])
  end

  it 'does not register an offense if Oj is used' do
    result = inspect_source(<<~RUBY)
      def shareable?
        metadata = Oj.load(extra)
        metadata && metadata['shareable']
      rescue StandardError
        false
      end
    RUBY

    expect(result.size).to eq(0)
  end

  it 'does not register an offense if JSON::Validator is used' do
    result = inspect_source(<<~RUBY)
      def validate(body)
        schema_validation_errors = JSON::Validator.fully_validate(@schema, body)
        raise ServiceBrokerResponseMalformed.new(schema_validation_errors) if schema_validation_errors.any?
      end
    RUBY

    expect(result.size).to eq(0)
  end
end
