# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Files do
  describe "GET /v2/apps/:id/instances/:instance_id/files/(:path)" do
    before :each do
      @app = Models::App.make
      @user =  make_user_for_space(@app.space)
      @developer = make_developer_for_space(@app.space)
    end

    context "as a developer" do
      it "should return 400 when bad instance id is used" do
        get("/v2/apps/#{@app.guid}/instances/bad_instance_id/files",
            {},
            headers_for(@developer))

        last_response.status.should == 400
      end

      it "should return 400 when there is an error finding the instance" do
        instance_id = 5

        @app.state = "STOPPED"
        @app.save

        get("/v2/apps/#{@app.guid}/instances/#{instance_id}/files",
            {},
            headers_for(@developer))

        last_response.status.should == 400
      end

      it "should return 400 when accessing of the file URL fails" do
        instance_id = 5

        @app.state = "STARTED"
        @app.instances = 10
        @app.save

        instance = {}
        instance[:file_uri] = "file_uri"
        instance[:staged] = ""
        instance[:credentials] = ["username", "password"]

        instance_json = Yajl::Encoder.encode(instance)

        MessageBus.should_receive(:request).once.and_return([instance_json])

        client = mock("http client")
        HTTPClient.should_receive(:new).and_return(client)
        client.should_receive(:set_auth).with(nil, "username", "password").once

        response = mock("http response")
        client.should_receive(:get).with("file_uri/").and_return(response)
        response.should_receive(:status).and_return(400)

        get("/v2/apps/#{@app.guid}/instances/#{instance_id}/files",
            {},
            headers_for(@developer))

        last_response.status.should == 400
      end

      it "should return the expected files when path is specified" do
        instance_id = 5

        @app.state = "STARTED"
        @app.instances = 10
        @app.save

        instance = {}
        instance[:file_uri] = "file_uri"
        instance[:staged] = ""
        instance[:credentials] = ["username", "password"]

        instance_json = Yajl::Encoder.encode(instance)

        MessageBus.should_receive(:request).once.and_return([instance_json])

        client = mock("http client")
        HTTPClient.should_receive(:new).and_return(client)
        client.should_receive(:set_auth).with(nil, "username", "password").once

        response = mock("http response")
        client.should_receive(:get).with("file_uri/path").and_return(response)
        response.should_receive(:status).and_return(200)
        response.should_receive(:body).and_return("files")

        get("/v2/apps/#{@app.guid}/instances/#{instance_id}/files/path",
            {},
            headers_for(@developer))

        last_response.status.should == 200
        last_response.body.should == "files"
      end

      it "should return the expected files when no path is specified" do
        instance_id = 5

        @app.state = "STARTED"
        @app.instances = 10
        @app.save

        instance = {}
        instance[:file_uri] = "file_uri"
        instance[:staged] = ""
        instance[:credentials] = ["username", "password"]

        instance_json = Yajl::Encoder.encode(instance)

        MessageBus.should_receive(:request).once.and_return([instance_json])

        client = mock("http client")
        HTTPClient.should_receive(:new).and_return(client)
        client.should_receive(:set_auth).with(nil, "username", "password").once

        response = mock("http response")
        client.should_receive(:get).with("file_uri/").and_return(response)
        response.should_receive(:status).and_return(200)
        response.should_receive(:body).and_return("files")

        get("/v2/apps/#{@app.guid}/instances/#{instance_id}/files",
            {},
            headers_for(@developer))

        last_response.status.should == 200
        last_response.body.should == "files"
      end
    end

    context "as a user" do
      it "should return 403" do
        get("/v2/apps/#{@app.guid}/instances/bad_instance_id/files",
            {},
            headers_for(@user))

        last_response.status.should == 403

        @app.state = "STARTED"
        @app.instances = 10
        @app.save

        get("/v2/apps/#{@app.guid}/instances/5/files",
            {},
            headers_for(@user))

        last_response.status.should == 403

        get("/v2/apps/#{@app.guid}/instances/5/files/path",
            {},
            headers_for(@user))

        last_response.status.should == 403
      end
    end
  end
end
