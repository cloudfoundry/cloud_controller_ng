# Copyright (c) 2009-2012 VMware, Inc.
require File.expand_path("../spec_helper", __FILE__)

describe "Sinatra::Consumes" do
  class TestApp < Sinatra::Base
    register Sinatra::Consumes

    mime_type :tgz, "application/x-compressed"

    put "/none" do
      "ok"
    end

    put "/json", :consumes => :json do
      "ok"
    end

    put "/tgz", :consumes => :tgz do
      "ok"
    end

    put "/json_tgz", :consumes => [:json, :tgz] do
      "ok"
    end
  end

  def app
    TestApp.new
  end

  def validate_ok
    last_response.status.should == 200
    last_response.body.should == "ok"
  end

  it "should return success for routes without a :consumes" do
    put "/none"
    validate_ok
  end

  it "should return success when sent the right mime type" do
    put "/json", {}, { "CONTENT_TYPE" => "application/json" }
    validate_ok
  end

  it "should return success for registered mime types" do
    put "/tgz", {}, { "CONTENT_TYPE" => "application/x-compressed" }
    validate_ok
  end

  it "should return success when sent one of many right mime types" do
    put "/json_tgz", {}, { "CONTENT_TYPE" => "application/x-compressed" }
    validate_ok
  end

  it "should return 404 for incorrect mime types" do
    put "/json", {}, { "CONTENT_TYPE" => "application/x-compressed" }
    last_response.status.should == 404
  end
end
