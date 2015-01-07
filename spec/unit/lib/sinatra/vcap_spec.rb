require 'spec_helper'

describe 'Sinatra::VCAP', type: :controller do
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

    def in_test_mode?
      false
    end

    get '/' do
      'ok'
    end

    get '/div_0' do
      begin
        1 / 0
      rescue => e
        e.set_backtrace(['/foo:1', '/bar:2'])
        raise e
      end
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
      e = VCAP::Errors::ApiError.new_from_details('MessageParseError', 'some message')
      e.set_backtrace(['/vcap:1', '/error:2'])
      raise e
    end
  end

  def app
    TestApp.new
  end

  before do
    VCAP::Component.varz.synchronize do
      # always start with an empty list of errors so we can check size later
      VCAP::Component.varz[:vcap_sinatra][:recent_errors].clear

      @orig_varz = VCAP::Component.varz[:vcap_sinatra].dup
    end
    @orig_requests = @orig_varz[:requests].dup
    @orig_completed = @orig_requests[:completed]
    @orig_http_status = @orig_varz[:http_status].dup
  end

  shared_examples 'vcap sinatra varz stats' do |expected_response|
    it 'should increment the number of completed ops' do
      completed = nil
      VCAP::Component.varz.synchronize do
        completed = VCAP::Component.varz[:vcap_sinatra][:requests][:completed]
      end

      expect(completed).to eq(@orig_completed + 1)
    end

    it "should increment the number of #{expected_response}s" do
      http_status = nil
      VCAP::Component.varz.synchronize do
        http_status = VCAP::Component.varz[:vcap_sinatra][:http_status]
      end

      http_status.each do |code, num|
        expected_num = @orig_http_status[code]
        expected_num += 1 if code == expected_response
        expect(num).to eq(expected_num)
      end
    end
  end

  shared_examples 'vcap request id' do
    it 'should return the request guid in the header' do
      expect(last_response.headers['X-VCAP-Request-ID']).not_to be_nil
    end
  end

  shared_examples 'http header content type' do
    it 'should return json content type in the header' do
      expect(last_response.headers['Content-Type']).to eql('application/json;charset=utf-8')
    end
  end

  describe 'access with no errors' do
    before do
      get '/'
    end

    it 'should return success' do
      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq('ok')
    end

    include_examples 'vcap sinatra varz stats', 200
    include_examples 'vcap request id'
    include_examples 'http header content type'
  end

  describe 'accessing an invalid route' do
    before do
      expect(Steno.logger('vcap_spec')).not_to receive(:error)
      get '/not_found'
    end

    it 'should return a 404' do
      expect(last_response.status).to eq(404)
      expect(decoded_response['code']).to eq(10000)
      expect(decoded_response['description']).to match(/Unknown request/)
    end

    include_examples 'vcap sinatra varz stats', 404
    include_examples 'vcap request id'
    include_examples 'http header content type'
  end

  describe 'accessing a route that throws a low level exception' do
    before do
      expect(Steno.logger('vcap_spec')).to receive(:error).once
      get '/div_0'
    end

    it 'should return 500' do
      expect(last_response.status).to eq(500)
      expect(decoded_response).to eq({
                                       'code' => 10001,
                                       'error_code' => 'UnknownError',
                                       'description' => 'An unknown error occurred.'
                                     })
    end

    it 'should add an entry to varz recent errors' do
      recent_errors = nil
      VCAP::Component.varz.synchronize do
        recent_errors = VCAP::Component.varz[:vcap_sinatra][:recent_errors]
      end
      expect(recent_errors.size).to eq(1)
      expect(recent_errors[0]).to be_an_instance_of(Hash)
    end

    include_examples 'vcap sinatra varz stats', 500
    include_examples 'vcap request id'
    include_examples 'http header content type'
  end

  describe 'accessing a route that throws a vcap error' do
    before do
      expect(Steno.logger('vcap_spec')).to receive(:info).once
      get '/vcap_error'
    end

    it 'should return 400' do
      expect(last_response.status).to eq(400)
    end

    it 'should return structure' do
      decoded_response = MultiJson.load(last_response.body)
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

    it 'should return 418' do
      expect(last_response.status).to eq(418)
    end

    it 'should return structure' do
      decoded_response = MultiJson.load(last_response.body)
      expect(decoded_response['code']).to eq(10001)
      expect(decoded_response['description']).to eq('boring message')

      expect(decoded_response['error_code']).to eq('CF-StructuredErrorWithResponseCode')
    end
  end

  describe 'accessing vcap request id from inside the app' do
    before do
      get '/request_id'
    end

    it 'should access the request id via Thread.current[:request_id]' do
      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq(last_response.headers['X-VCAP-Request-ID'])
    end
  end

  describe 'caller provided x-vcap-request-id' do
    before do
      get '/request_id', {}, { 'HTTP_X_VCAP_REQUEST_ID' => 'abcdef' }
    end

    it 'should set the X-VCAP-Request-ID to the caller specified value' do
      expect(last_response.status).to eq(200)
      expect(last_response.headers['X-VCAP-Request-ID']).to match /abcdef::.*/
    end

    it 'should access the request id via Thread.current[:request_id]' do
      expect(last_response.status).to eq(200)
      expect(last_response.body).to match /abcdef::.*/
    end
  end

  describe 'caller provided x-request-id' do
    before do
      get '/request_id', {}, { 'HTTP_X_REQUEST_ID' => 'abcdef' }
    end

    it 'should set the X-VCAP-Request-ID to the caller specified value' do
      expect(last_response.status).to eq(200)
      expect(last_response.headers['X-VCAP-Request-ID']).to match /abcdef::.*/
    end

    it 'should access the request id via Thread.current[:request_id]' do
      expect(last_response.status).to eq(200)
      expect(last_response.body).to match /abcdef::.*/
    end
  end

  describe 'caller provided x-request-id and x-vcap-request-id' do
    before do
      get '/request_id', {}, { 'HTTP_X_REQUEST_ID' => 'abc', 'HTTP_X_VCAP_REQUEST_ID' => 'def' }
    end

    it 'should set the X-VCAP-Request-ID to the caller specified value of X-VCAP-Request-ID' do
      expect(last_response.status).to eq(200)
      expect(last_response.headers['X-VCAP-Request-ID']).to match /def::.*/
    end

    it 'should access the request id via Thread.current[:request_id]' do
      expect(last_response.status).to eq(200)
      expect(last_response.body).to match /def::.*/
    end
  end

  describe 'current request information for diagnostics' do
    before do
      get '/current_request'
    end

    def request_info
      MultiJson.load(last_response.body)
    end

    it 'populates the correct request id' do
      expect(request_info['request_id']).to eq(last_response.headers['X-VCAP-Request-ID'])
    end

    it 'populates the request uri and method' do
      expect(request_info['request_method']).to eq('GET')
      expect(request_info['request_uri']).to eq('/current_request')
    end
  end
end
