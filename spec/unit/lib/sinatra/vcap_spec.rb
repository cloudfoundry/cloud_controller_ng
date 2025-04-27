require 'spec_helper'

RSpec.describe 'Sinatra::VCAP', type: :v2_controller do
  class StructuredErrorWithResponseCode < StructuredError
    def initialize
      super('boring message', 'the source')
    end

    def response_code
      418
    end
  end

  class TestApp < Sinatra::Base
    register Sinatra::VCAP
    vcap_configure logger_name: 'vcap_spec'

    module TestModeHelpers
      def in_test_mode?
        false
      end
    end

    helpers TestModeHelpers

    get '/' do
      'ok'
    end

    get '/div_0' do
      1 / 0
    rescue StandardError => e
      e.set_backtrace(['/foo:1', '/bar:2'])
      raise e
    end

    get '/request_id' do
      VCAP::Request.current_id
    end

    get '/current_request' do
      Thread.current[:current_request].to_json
    end

    get '/structured_error' do
      e = StructuredErrorWithResponseCode.new
      e.set_backtrace(['/foo:1', '/bar:2'])
      raise e
    end

    get '/vcap_error' do
      e = CloudController::Errors::ApiError.new_from_details('MessageParseError', 'some message')
      e.set_backtrace(['/vcap:1', '/error:2'])
      raise e
    end
  end

  def app
    TestApp.new
  end

  shared_examples 'http header content type' do
    it 'returns json content type in the header' do
      expect(last_response.headers['Content-Type']).to eql('application/json;charset=utf-8')
    end
  end

  describe 'access with no errors' do
    before do
      get '/'
    end

    it 'returns success' do
      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq('ok')
    end

    include_examples 'http header content type'
  end

  describe 'accessing an invalid route' do
    before do
      expect(Steno.logger('vcap_spec')).not_to receive(:error)
      get '/not_found'
    end

    it 'returns a 404' do
      expect(last_response.status).to eq(404)
      expect(decoded_response['code']).to eq(10_000)
      expect(decoded_response['description']).to match(/Unknown request/)
    end

    include_examples 'http header content type'
  end

  describe 'accessing a route that throws a low level exception' do
    before do
      expect(Steno.logger('vcap_spec')).to receive(:error).once
      get '/div_0'
    end

    it 'returns 500' do
      expect(last_response.status).to eq(500)
      expect(decoded_response).to eq({
                                       'code' => 10_001,
                                       'error_code' => 'UnknownError',
                                       'description' => 'An unknown error occurred.'
                                     })
    end

    include_examples 'http header content type'
  end

  describe 'accessing a route that throws a vcap error' do
    before do
      expect(Steno.logger('vcap_spec')).to receive(:info).once
      get '/vcap_error'
    end

    it 'returns 400' do
      expect(last_response.status).to eq(400)
    end

    it 'returns structure' do
      decoded_response = Oj.load(last_response.body)
      expect(decoded_response['code']).to eq(1001)
      expect(decoded_response['description']).to eq('Request invalid due to parse error: some message')

      expect(decoded_response['error_code']).to eq('CF-MessageParseError')
    end
  end

  describe 'accessing a route that throws a StructuredError' do
    before do
      expect(Steno.logger('vcap_spec')).to receive(:info).once
      get '/structured_error'
    end

    it 'returns 418' do
      expect(last_response.status).to eq(418)
    end

    it 'returns structure' do
      decoded_response = Oj.load(last_response.body)
      expect(decoded_response['code']).to eq(10_001)
      expect(decoded_response['description']).to eq('boring message')

      expect(decoded_response['error_code']).to eq('CF-StructuredErrorWithResponseCode')
    end
  end

  describe 'current request information for diagnostics' do
    before do
      get '/current_request'
    end

    def request_info
      Oj.load(last_response.body)
    end

    it 'populates the request uri and method' do
      expect(request_info['request_method']).to eq('GET')
      expect(request_info['request_uri']).to eq('/current_request')
    end
  end
end
