require 'spec_helper'

describe HttpError do
  let(:endpoint) { 'http://www.example.com/' }
  let(:response_body) do
    { 'foo' => 'bar' }.to_json
  end
  let(:response) { double(code: 500, reason: 'Internal Server Error', body: response_body) }

  before do
    class ChildError < HttpError
      CODE=12534
      def msg
        "I am a child of HttpError"
      end
    end
  end

  after do
    Object.send(:remove_const, :ChildError)
  end

  it 'parses the response as JSON' do
    exception = ChildError.new(endpoint, response, 'GET')

    expect(exception.error).to eq({
      'foo' => 'bar'
    })
  end

  context 'when the response body is plain text' do
    let(:response_body) { 'not JSON' }

    it 'parses the response as plain text' do
      exception = ChildError.new(endpoint, response, 'GET')

      expect(exception.error).to eq('not JSON')
    end
  end


end

describe NonResponsiveHttpError do
  let(:endpoint) { 'http://www.example.com/' }
  let(:nested_exception) { SocketError.new }

  after do
    Object.send(:remove_const, :ChildError)
  end

  context "without a child msg class" do
    before do
      class ChildError < NonResponsiveHttpError
        CODE=12534
      end
    end

    it 'warns the user of this class' do
      expect { ChildError.new(endpoint, 'PUT', nested_exception) }.to raise_error(RuntimeError,
      "Error message required.  Please define ChildError#msg.")
    end
  end

  context "without a child class (vcap error) CODE constant" do
    before do
      class ChildError < NonResponsiveHttpError
        def msg
          "I am a child of NonResponsiveHttpError"
        end
      end
    end

    it 'warns the user of this class' do
      expect { ChildError.new(endpoint, 'PUT', nested_exception) }.to raise_error(RuntimeError,
        "CODE required.  Please define constant ChildError::CODE as an integer matching v2.yml")
    end
  end

  context "with msg and CODE defined" do
    before do
      class ChildError < NonResponsiveHttpError
        CODE=12534
        def msg
          "I am a child of NonResponsiveHttpError"
        end
      end
    end

    it 'successfully inherits from NonResponsiveHttpError' do
      ChildError.new(endpoint, 'PUT', nested_exception)
    end
  end


end
