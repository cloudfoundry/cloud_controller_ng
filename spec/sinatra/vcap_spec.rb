require 'spec_helper'

describe 'Sinatra::VCAP' do
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

    vcap_configure :logger_name => 'vcap_spec'

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

    get '/structured_error' do
      e = StructuredErrorWithResponseCode.new
      e.set_backtrace(['/foo:1', '/bar:2'])
      raise e
    end

    get '/vcap_error' do
      e = VCAP::Errors::MessageParseError.new('some message')
      e.set_backtrace(['/vcap:1', '/error:2'])
      raise e
    end

    get '/active_varz' do
      VCAP::Component.varz.synchronize do
        VCAP::Component.varz[:vcap_sinatra].to_json
      end
    end

    put '/active_varz' do
      VCAP::Component.varz.synchronize do
        VCAP::Component.varz[:vcap_sinatra].to_json
      end
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

      completed.should == @orig_completed + 1
    end

    it "should increment the number of #{expected_response}s" do
      http_status = nil
      VCAP::Component.varz.synchronize do
        http_status = VCAP::Component.varz[:vcap_sinatra][:http_status]
      end

      http_status.each do |code, num|
        expected_num = @orig_http_status[code]
        expected_num += 1 if code == expected_response
        num.should == expected_num
      end
    end
  end

  shared_examples 'vcap request id' do
    it 'should return the request guid in the header' do
      last_response.headers['X-VCAP-Request-ID'].should_not be_nil
    end
  end

  shared_examples 'http header content type' do
    it 'should return json content type in the header' do
      last_response.headers['Content-Type'].should eql('application/json;charset=utf-8')
    end
  end

  describe 'access with no errors' do
    before do
      get '/'
    end

    it 'should return success' do
      last_response.status.should == 200
      last_response.body.should == 'ok'
    end

    include_examples 'vcap sinatra varz stats', 200
    include_examples 'vcap request id'
    include_examples 'http header content type'
  end

  describe 'accessing an invalid route' do
    before do
      Steno.logger('vcap_spec').should_not_receive(:error)
      get '/not_found'
    end

    it 'should return a 404' do
      last_response.status.should == 404
    end

    include_examples 'vcap sinatra varz stats', 404
    include_examples 'vcap request id'
    include_examples 'http header content type'
    it_behaves_like 'a vcap rest error response', /Unknown request/
  end

  describe 'accessing a route that throws a low level exception' do
    before do
      TestApp.any_instance.stub(:in_test_mode?).and_return(false)
      Steno.logger('vcap_spec').should_receive(:error).once
      get '/div_0'
    end

    it 'should return 500' do
      last_response.status.should == 500
    end

    it 'should add an entry to varz recent errors' do
      recent_errors = nil
      VCAP::Component.varz.synchronize do
        recent_errors = VCAP::Component.varz[:vcap_sinatra][:recent_errors]
      end
      recent_errors.size.should == 1
    end

    include_examples 'vcap sinatra varz stats', 500
    include_examples 'vcap request id'
    include_examples 'http header content type'
    it_behaves_like 'a vcap rest error response'

    it 'returns an error structure' do
      decoded_response = Yajl::Parser.parse(last_response.body)
      expect(decoded_response).to eq({
                                       'code' => 10001,
                                       'error_code' => 'UnknownError',
                                       'description' => 'An unknown error occurred.'
                                     })
    end
  end

  describe 'accessing a route that throws a vcap error' do
    before do
      TestApp.any_instance.stub(:in_test_mode?).and_return(false)
      Steno.logger('vcap_spec').should_receive(:info).once
      get '/vcap_error'
    end

    it 'should return 400' do
      last_response.status.should == 400
    end

    it 'should return structure' do
      decoded_response = Yajl::Parser.parse(last_response.body)
      expect(decoded_response['code']).to eq(1001)
      expect(decoded_response['description']).to eq('Request invalid due to parse error: some message')

      expect(decoded_response['error_code']).to eq('CF-MessageParseError')
      expect(decoded_response['types']).to eq(['MessageParseError', 'Error'])
    end
  end

  describe 'accessing a route that throws a StructuredError' do
    before do
      TestApp.any_instance.stub(:in_test_mode?).and_return(false)
      Steno.logger('vcap_spec').should_receive(:info).once
      get '/structured_error'
    end

    it 'should return 418' do
      last_response.status.should == 418
    end

    it 'should return structure' do
      decoded_response = Yajl::Parser.parse(last_response.body)
      expect(decoded_response['code']).to eq(10001)
      expect(decoded_response['description']).to eq('boring message')

      expect(decoded_response['error_code']).to eq('CF-StructuredErrorWithResponseCode')
      expect(decoded_response['types']).to eq(['StructuredErrorWithResponseCode'])

      # temporarily removed pending security review
      #expect(decoded_response['source']).to eq('the source')
    end
  end

  describe 'accessing vcap request id from inside the app' do
    before do
      get '/request_id'
    end

    it 'should access the request id via Thread.current[:request_id]' do
      last_response.status.should == 200
      last_response.body.should == last_response.headers['X-VCAP-Request-ID']
    end
  end

  describe 'caller provided x-vcap-request-id' do
    before do
      get '/request_id', {}, {'X_VCAP_REQUEST_ID' => 'abcdef'}
    end

    it 'should set the X-VCAP-Request-ID to the caller specified value' do
      last_response.status.should == 200
      last_response.headers['X-VCAP-Request-ID'].should match /abcdef::.*/
    end

    it 'should access the request id via Thread.current[:request_id]' do
      last_response.status.should == 200
      last_response.body.should match /abcdef::.*/
    end
  end

  describe 'caller provided x-request-id' do
    before do
      get '/request_id', {}, {'X_REQUEST_ID' => 'abcdef'}
    end

    it 'should set the X-VCAP-Request-ID to the caller specified value' do
      last_response.status.should == 200
      last_response.headers['X-VCAP-Request-ID'].should match /abcdef::.*/
    end

    it 'should access the request id via Thread.current[:request_id]' do
      last_response.status.should == 200
      last_response.body.should match /abcdef::.*/
    end
  end

  describe 'caller provided x-request-id and x-vcap-request-id' do
    before do
      get '/request_id', {}, {'X_REQUEST_ID' => 'abc', 'X_VCAP_REQUEST_ID' => 'def'}
    end

    it 'should set the X-VCAP-Request-ID to the caller specified value of X_VCAP_REQUEST_ID' do
      last_response.status.should == 200
      last_response.headers['X-VCAP-Request-ID'].should match /def::.*/
    end

    it 'should access the request id via Thread.current[:request_id]' do
      last_response.status.should == 200
      last_response.body.should match /def::.*/
    end
  end

  describe 'varz information about outstanding requests' do
    before do
      get '/active_varz'
    end

    def sinatra_varz
      Yajl::Parser.parse(last_response.body)
    end

    def request_id
      last_response.headers['X-VCAP-Request-ID']
    end

    def varz_active_request
      sinatra_varz['outstanding_requests'][request_id]
    end

    it 'should indicate there is 1 outstanding request when processing the request' do
      sinatra_varz['requests']['outstanding'].should == 1
    end

    it 'should have data associated with the request_guid' do
      varz_active_request.should_not be_nil
      varz_active_request.should_not be_empty
    end

    it 'should have a valid start time' do
      varz_active_request.has_key?('start_time').should be_true
      varz_active_request['start_time'].should < Time.now.to_f
    end

    it 'should contain the id of the thread executing the request' do
      varz_active_request.has_key?('thread_id').should be_true
      varz_active_request['thread_id'].should == Thread.current.object_id
    end

    it 'should contain the request method used' do
      get '/active_varz'
      varz_active_request['request_method'].should == 'GET'

      put '/active_varz'
      varz_active_request['request_method'].should == 'PUT'
    end

    describe 'request_uri' do
      it 'should contain the requested uri' do
        varz_active_request['request_uri'].should eq('/active_varz')
      end

      context 'when a query string is provided' do
        before do
          get '/active_varz?query=true'
        end

        it 'should contain the path and query string in request_uri' do
          varz_active_request['request_uri'].should eq('/active_varz?query=true')
        end
      end
    end
  end
end
