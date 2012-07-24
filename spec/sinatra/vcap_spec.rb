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

  describe "access with no errors" do
    before do
      get "/"
    end

    it "should return success" do
      last_response.status.should == 200
      last_response.body.should == "ok"
    end
  end

  describe "accessing an invalid route" do
    before do
      Steno.logger("vcap_spec").should_not_receive(:error)
      get "/not_found"
    end

    it "should return a 404" do
      last_response.status.should == 404
    end

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

    it_behaves_like "a vcap rest error response", /Server error/
  end
end
