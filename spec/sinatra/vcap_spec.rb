require "spec_helper"

describe "Sinatra::VCAP" do
  class TestApp < Sinatra::Base
    register Sinatra::VCAP

    vcap_configure :logger_name => "vcap_spec"

    get "/" do
      "ok"
    end

    get "/div_0" do
      1 / 0
    end

    get "/request_id" do
      VCAP::Request.current_id
    end

    get "/structured_error" do
      raise StructuredError.new('some message', {'foo' => 'bar'})
    end
  end

  def app
    TestApp.new
  end

  before do
    VCAP::Component.varz.synchronize do
      @orig_varz = VCAP::Component.varz[:vcap_sinatra].dup
    end
    @orig_recent_errors = @orig_varz[:recent_errors].dup
    @orig_requests = @orig_varz[:requests].dup
    @orig_completed = @orig_requests[:completed]
    @orig_http_status = @orig_varz[:http_status].dup
  end

  shared_examples "vcap sinatra varz stats" do |expected_response|
    it "should increment the number of completed ops" do
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

  shared_examples "vcap request id" do
    it "should return the request guid in the header" do
      last_response.headers["X-VCAP-Request-ID"].should_not be_nil
    end
  end

  shared_examples "http header content type" do
    it "should return json content type in the header" do
      last_response.headers["Content-Type"].should eql("application/json;charset=utf-8")
    end
  end

  describe "access with no errors" do
    before do
      get "/"
    end

    it "should return success" do
      last_response.status.should == 200
      last_response.body.should == "ok"
    end

    include_examples "vcap sinatra varz stats", 200
    include_examples "vcap request id"
    include_examples "http header content type"
  end

  describe "accessing an invalid route" do
    before do
      Steno.logger("vcap_spec").should_not_receive(:error)
      get "/not_found"
    end

    it "should return a 404" do
      last_response.status.should == 404
    end

    include_examples "vcap sinatra varz stats", 404
    include_examples "vcap request id"
    include_examples "http header content type"
    it_behaves_like "a vcap rest error response", /Unknown request/
  end

  describe "accessing a route that throws a low level exception" do
    before do
      TestApp.any_instance.stub(:in_test_mode?).and_return(false)
      Steno.logger("vcap_spec").should_receive(:error).once
      get "/div_0"
    end

    it "should return 500" do
      last_response.status.should == 500
    end

    it "should add an entry to varz recent errors" do
      recent_errors = nil
      VCAP::Component.varz.synchronize do
        recent_errors = VCAP::Component.varz[:vcap_sinatra][:recent_errors]
      end
      recent_errors.size.should == @orig_recent_errors.size + 1
    end

    include_examples "vcap sinatra varz stats", 500
    include_examples "vcap request id"
    include_examples "http header content type"
    it_behaves_like "a vcap rest error response", /ZeroDivisionError: divided by 0/
  end

  describe "accessing a route that throws a StructuredError" do
    before do
      TestApp.any_instance.stub(:in_test_mode?).and_return(false)
      Steno.logger("vcap_spec").should_receive(:error).once
      get "/structured_error"
    end

    it "should return 500" do
      last_response.status.should == 500
    end

    it "should return structure" do
      decoded_response = Yajl::Parser.parse(last_response.body)
      expect(decoded_response['code']).to eq(10001)
      expect(decoded_response['description']).to eq('some message')
      expect(decoded_response['types']).to eq(%w(StructuredError StandardError))
      expect(decoded_response['backtrace']).to be
      expect(decoded_response['error']).to eq({ 'foo' => 'bar' })
    end
  end


  describe "accessing vcap request id from inside the app" do
    before do
      get "/request_id"
    end

    it "should access the request id via Thread.current[:request_id]" do
      last_response.status.should == 200
      last_response.body.should == last_response.headers["X-VCAP-Request-ID"]
    end
  end

  describe "caller provided x-vcap-request-id" do
    before(:all) do
      get "/request_id", {}, { "X_VCAP_REQUEST_ID" => "abcdef" }
    end

    it "should set the X-VCAP-Request-ID to the caller specified value" do
      last_response.status.should == 200
      last_response.headers["X-VCAP-Request-ID"].should match /abcdef::.*/
    end

    it "should access the request id via Thread.current[:request_id]" do
      last_response.status.should == 200
      last_response.body.should match /abcdef::.*/
    end
  end

  describe "caller provided x-request-id" do
    before(:all) do
      get "/request_id", {}, { "X_REQUEST_ID" => "abcdef" }
    end

    it "should set the X-VCAP-Request-ID to the caller specified value" do
      last_response.status.should == 200
      last_response.headers["X-VCAP-Request-ID"].should match /abcdef::.*/
    end

    it "should access the request id via Thread.current[:request_id]" do
      last_response.status.should == 200
      last_response.body.should match /abcdef::.*/
    end
  end

  describe "caller provided x-request-id and x-vcap-request-id" do
    before(:all) do
      get "/request_id", {}, { "X_REQUEST_ID" => "abc", "X_VCAP_REQUEST_ID" => "def" }
    end

    it "should set the X-VCAP-Request-ID to the caller specified value of X_VCAP_REQUEST_ID" do
      last_response.status.should == 200
      last_response.headers["X-VCAP-Request-ID"].should match /def::.*/
    end

    it "should access the request id via Thread.current[:request_id]" do
      last_response.status.should == 200
      last_response.body.should match /def::.*/
    end
  end
end
