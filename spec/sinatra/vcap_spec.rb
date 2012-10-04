# Copyright (c) 2009-2012 VMware, Inc.
require File.expand_path("../spec_helper", __FILE__)

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
  end

  def app
    TestApp.new
  end

  before do
    VCAP::Component.varz.synchronize do
      @orig_varz = VCAP::Component.varz[:vcap_sinatra].dup
    end
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

  describe "access with no errors" do
    before do
      get "/"
    end

    it "should return success" do
      last_response.status.should == 200
      last_response.body.should == "ok"
    end

    include_examples "vcap sinatra varz stats", 200
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
    it_behaves_like "a vcap rest error response", /Unknown request/
  end

  describe "accessing a route that throws a low level exception" do
    before do
      Steno.logger("vcap_spec").should_receive(:error).once
      get "/div_0"
    end

    it "should return 500" do
      last_response.status.should == 500
    end

    include_examples "vcap sinatra varz stats", 500
    it_behaves_like "a vcap rest error response", /Server error/
  end
end
