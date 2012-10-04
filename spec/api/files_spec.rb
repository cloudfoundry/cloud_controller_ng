# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Files do
    describe "GET /v2/apps/:id/instances/:instance_id/files/(:path)" do
      before :each do
        @app = Models::App.make
        @user =  make_user_for_space(@app.space)
        @developer = make_developer_for_space(@app.space)
      end

      before :each, :use_nginx => false do
        config_override(:nginx => { :use_nginx => false })
      end

      context "as a developer" do
        it "should return 400 when bad instance id is used" do
          get("/v2/apps/#{@app.guid}/instances/bad_instance_id/files",
              {},
              headers_for(@developer))

          last_response.status.should == 400

          get("/v2/apps/#{@app.guid}/instances/-1/files",
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

        it "should return 400 when accessing of the file URL fails", :use_nginx => false do
          instance_id = 5

          @app.state = "STARTED"
          @app.instances = 10
          @app.save
          @app.refresh

          to_return = { :uri => "file_uri/",
            :credentials => ["username", "password"],
            :file_uri_v2 => false }
          DeaClient.should_receive(:get_file_uri).with(@app, 5, nil).
            and_return(to_return)

          client = mock("http client")
          HTTPClient.should_receive(:new).and_return(client)
          client.should_receive(:set_auth).with(nil, "username", "password")

          response = mock("http response")
          client.should_receive(:get).with(
            "file_uri/", :header => {}).and_return(response)
          response.should_receive(:status).and_return(400)

          get("/v2/apps/#{@app.guid}/instances/#{instance_id}/files",
              {},
              headers_for(@developer))

          last_response.status.should == 400
        end

        it "should return the expected files when path is specified", :use_nginx => false do
          instance_id = 5

          @app.state = "STARTED"
          @app.instances = 10
          @app.save
          @app.refresh

          to_return = { :uri => "file_uri/path",
            :credentials => ["username", "password"],
            :file_uri_v2 => false }
          DeaClient.should_receive(:get_file_uri).with(@app, 5, "path").
            and_return(to_return)

          client = mock("http client")
          HTTPClient.should_receive(:new).and_return(client)
          client.should_receive(:set_auth).with(nil, "username", "password")

          response = mock("http response")
          client.should_receive(:get).with(
            "file_uri/path", :header => {}).and_return(response)
          response.should_receive(:status).at_least(:once).and_return(200)
          response.should_receive(:body).and_return("files")

          get("/v2/apps/#{@app.guid}/instances/#{instance_id}/files/path",
              {},
              headers_for(@developer))

          last_response.status.should == 200
          last_response.body.should == "files"
        end

        it "should return the expected files when no path is specified", :use_nginx => false do
          instance_id = 5

          @app.state = "STARTED"
          @app.instances = 10
          @app.save
          @app.refresh

          to_return = { :uri => "file_uri/",
            :credentials => ["username", "password"],
            :file_uri_v2 => false }
          DeaClient.should_receive(:get_file_uri).with(@app, 5, nil).
            and_return(to_return)

          client = mock("http client")
          HTTPClient.should_receive(:new).and_return(client)
          client.should_receive(:set_auth).with(nil, "username", "password")

          response = mock("http response")
          client.should_receive(:get).with(
            "file_uri/", :header => {}).and_return(response)
          response.should_receive(:status).at_least(:once).and_return(200)
          response.should_receive(:body).and_return("files")

          get("/v2/apps/#{@app.guid}/instances/#{instance_id}/files",
              {},
              headers_for(@developer))

          last_response.status.should == 200
          last_response.body.should == "files"
        end

        it "should forward the http range request", :use_nginx => false do
          instance_id = 5
          range = "bytes=100-200"

          @app.state = "STARTED"
          @app.instances = 10
          @app.save
          @app.refresh

          to_return = { :uri => "file_uri/",
            :credentials => ["username", "password"],
            :file_uri_v2 => false }
          DeaClient.should_receive(:get_file_uri).with(@app, 5, nil).
            and_return(to_return)

          client = mock("http client")
          HTTPClient.should_receive(:new).and_return(client)
          client.should_receive(:set_auth).with(nil, "username", "password")

          response = mock("http response")
          client.should_receive(:get).with(
            "file_uri/", :header => { "range" => range } ).and_return(response)
          response.should_receive(:status).at_least(:once).and_return(206)
          response.should_receive(:body).and_return("files")

          get("/v2/apps/#{@app.guid}/instances/#{instance_id}/files",
              {},
              headers_for(@developer).merge("HTTP_RANGE" => range))

          last_response.status.should == 206
          last_response.body.should == "files"
        end

        it "should accept tail query parameter (non-nginx)", :use_nginx => false do
          instance_id = 5

          @app.state = "STARTED"
          @app.instances = 10
          @app.save
          @app.refresh

          to_return = { :uri => "file_uri",
            :credentials => ["username", "password"],
            :file_uri_v2 => false }
          DeaClient.should_receive(:get_file_uri).with(@app, 5, "path").
            and_return(to_return)

          client = mock("http client")
          HTTPClient.should_receive(:new).and_return(client)
          client.should_receive(:set_auth).with(nil, "username", "password")

          response = mock("http response")
          client.should_receive(:get).with(
            "file_uri&tail", :header => {}).and_return(response)
          response.should_receive(:status).at_least(:once).and_return(200)
          response.should_receive(:body).and_return("files")

          get("/v2/apps/#{@app.guid}/instances/#{instance_id}/files/path?tail",
              {},
              headers_for(@developer))

          last_response.status.should == 200
          last_response.body.should == "files"
        end

        it "should accept tail query parameter" do
          instance_id = 5

          @app.state = "STARTED"
          @app.instances = 10
          @app.save
          @app.refresh

          DeaClient.should_receive(:get_file_uri).with(@app, 5, "path").
            and_return(
              {
                :uri => "http://1.2.3.4/foo/path",
                :credentials => ["u", "p"],
              }
            )

          get("/v2/apps/#{@app.guid}/instances/#{instance_id}/files/path?tail",
              {},
              headers_for(@developer))

          last_response.status.should == 200
          last_response.headers.should include(
            {
              "X-Accel-Redirect" => "/internal_redirect/http://1.2.3.4/foo/path&tail",
              # "dTpw" is ["u:p"].pack("m0")
              "X-Auth" => "Basic dTpw",
            }
          )
        end

        it "should ignore absence of credentials in dea response", :use_nginx => false do
          instance_id = 5

          @app.state = "STARTED"
          @app.instances = 10
          @app.save
          @app.refresh

          to_return = { :uri => "file_uri/", :file_uri_v2 => true }
          DeaClient.should_receive(:get_file_uri).with(@app, 5, nil).
            and_return(to_return)

          client = mock("http client")
          HTTPClient.should_receive(:new).and_return(client)

          response = mock("http response")
          client.should_receive(:get).with(
            "file_uri/", :header => {}).and_return(response)
          response.should_receive(:status).at_least(:once).and_return(200)
          response.should_receive(:body).and_return("files")

          get("/v2/apps/#{@app.guid}/instances/#{instance_id}/files",
              {},
              headers_for(@developer))

          last_response.status.should == 200
          last_response.body.should == "files"
        end

        it "should return the staging task log if it exists" do
          redis_client = mock("redis")

          task_log = StagingTaskLog.new(@app.guid, "task log", redis_client)
          Redis.stub(:new).and_return(redis_client)
          StagingTaskLog.should_receive(:fetch).with(@app.guid, redis_client)
            .and_return(task_log)

          get("/v2/apps/#{@app.guid}/instances/1/files/logs/staging.log",
              {},
              headers_for(@developer))

          last_response.status.should == 200
          last_response.body.should == "task log"
        end

        it "should return 404 if staging task log is absent" do
          redis_client = mock("redis")

          Redis.stub(:new).and_return(redis_client)
          StagingTaskLog.should_receive(:fetch).with(@app.guid, redis_client)
            .and_return(nil)

          get("/v2/apps/#{@app.guid}/instances/1/files/logs/staging.log",
              {},
              headers_for(@developer))

          last_response.status.should == 404
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
end
