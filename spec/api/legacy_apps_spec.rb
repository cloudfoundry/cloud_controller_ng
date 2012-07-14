require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::LegacyApps do
  let(:user) { make_user_with_default_app_space }
  let(:admin) { make_user_with_default_app_space(:admin => true) }

  describe "GET /apps" do
    before do
      @apps = []
      7.times do
        @apps << Models::App.make(:app_space => user.default_app_space)
      end

      3.times do
        app_space = make_app_space_for_user(user)
        Models::App.make(:app_space => app_space)
      end

      get "/apps", {}, headers_for(user)
    end

    it "should return success" do
      last_response.status.should == 200
    end

    it "should return an array" do
      decoded_response.should be_a_kind_of(Array)
    end

    it "should only return apps for the default app space" do
      decoded_response.length.should == 7
    end

    it "should return app names" do
      names = decoded_response.map { |a| a["name"] }
      expected_names = @apps.map { |a| a.name }
      names.should == expected_names
    end
  end

  describe "GET /apps/:name" do
    before do
      # since we don't get the guid back, we use the mem attribute to
      # distinguish between apps
      @app_1 = Models::App.make(:app_space => user.default_app_space, :memory => 128)
      @app_2 = Models::App.make(:app_space => user.default_app_space, :memory => 256)
      @app_3 = Models::App.make(:app_space => user.default_app_space, :memory => 512)

      # used to make sure we are getting the name from the correct app space,
      # i.e. we *don't* want to get this one back
      Models::App.make(:name => @app_2.name,
                       :app_space => make_app_space_for_user(user), :memory => 1024)

    end

    describe "GET /apps/:name_that_exists" do
      before do
        get "/apps/#{@app_2.name}", {}, headers_for(user)
      end

      it "should return success" do
        last_response.status.should == 200
      end

      it "should return a hash" do
        decoded_response.should be_a_kind_of(Hash)
      end

      it "should return the app with the correct name" do
        decoded_response["name"].should == @app_2.name
      end

      it "should return the version from the default app space" do
        decoded_response["resources"]["memory"].should == 256
      end
    end

    describe "GET /apps/:invalid_name" do
      before do
        get "/apps/name_does_not_exist", {}, headers_for(user)
      end

      it "should return an error" do
        last_response.status.should == 400
      end

      it_behaves_like "a vcap rest error response", /app name could not be found: name_does_not_exist/
    end
  end

  describe "POST /apps" do
    before do
      3.times { Models::App.make }

      Models::Framework.make(:name => "sinatra")
      Models::Runtime.make(:name => "ruby18")
      @num_apps_before = Models::App.count
    end

    context "with all required parameters" do
      before do
        req = Yajl::Encoder.encode({
          :name => "app_name",
          :staging => { :framework => "sinatra", :runtime => "ruby18" },
        })

        post "/apps", req, headers_for(user)
      end

      it "should return success" do
        last_response.status.should == 200
      end

      it "should add the app the default app space" do
        app = user.default_app_space.apps.find(:name => "app_name")
        app.should_not be_nil
        Models::App.count.should == @num_apps_before + 1
      end
    end

    context "with an invalid framework" do
      before do
        req = Yajl::Encoder.encode({
          :name => "app_name",
          :staging => { :framework => "funky", :runtime => "ruby18" },
        })

        post "/apps", req, headers_for(user)
      end

      it "should return bad request" do
        last_response.status.should == 400
      end

      it "should not add an app" do
        Models::App.count.should == @num_apps_before
      end

      it_behaves_like "a vcap rest error response", /framework can not be found: funky/
    end

    context "with an invalid runtime" do
      before do
        req = Yajl::Encoder.encode({
          :name => "app_name",
          :staging => { :framework => "sinatra", :runtime => "cobol" },
        })

        post "/apps", req, headers_for(user)
      end

      it "should return bad request" do
        last_response.status.should == 400
      end

      it "should not add an app" do
        Models::App.count.should == @num_apps_before
      end

      it_behaves_like "a vcap rest error response", /runtime can not be found: cobol/
    end
  end

  describe "PUT /apps/:name" do
    let(:app_obj) { Models::App.make(:app_space => user.default_app_space) }

    context "with valid attributes" do
      before do
        @expected_mem = app_obj.memory * 2
        req = Yajl::Encoder.encode(:resources => { :memory => @expected_mem })
        put "/apps/#{app_obj.name}", req, headers_for(user)
        app_obj.refresh
      end

      it "should return success" do
        last_response.status.should == 200
      end

      it "should update the app" do
        app_obj.memory.should == @expected_mem
      end
    end

    context "with an invalid runtime" do
      before do
        req = Yajl::Encoder.encode(:staging => { :runtime => "cobol" })
        put "/apps/#{app_obj.name}", req, headers_for(user)
      end

      it "should return bad request" do
        last_response.status.should == 400
      end

      it_behaves_like "a vcap rest error response", /runtime can not be found: cobol/
    end

    describe "GET /apps/:invalid_name" do
      before do
        put "/apps/name_does_not_exist", {}, headers_for(user)
      end

      it "should return an error" do
        last_response.status.should == 400
      end

      it_behaves_like "a vcap rest error response", /app name could not be found: name_does_not_exist/
    end
  end

  describe "DELETE /apps/:name" do
    let(:app_obj) { Models::App.make(:app_space => user.default_app_space) }

    before do
      3.times { Models::App.make }
      app_obj.guid.should_not be_nil
      @num_apps_before = Models::App.count
      delete "/apps/#{app_obj.name}", {}, headers_for(user)
    end

    it "should return success" do
      last_response.status.should == 200
    end

    it "should reduce the app count by 1" do
      Models::App.count.should == @num_apps_before - 1
    end
  end

  # FIXME: this still needs to switch from admin to user.  This can't happen
  # until services get correct permission settings
  describe "service binding" do
    describe "PUT /apps/:name adding and removing bindings" do
      before(:all) do
        @app_obj = Models::App.make(:app_space => admin.default_app_space)
        bound_instances = []
        5.times do
          instance = Models::ServiceInstance.make(:app_space => admin.default_app_space)
          bound_instances << instance
          Models::ServiceBinding.make(:app => @app_obj, :service_instance => instance)
        end

        @instance_to_bind = Models::ServiceInstance.make(:app_space => admin.default_app_space)
        @instance_to_unbind = bound_instances[2]

        service_instance_names = [@instance_to_bind.name]
        bound_instances.each do |i|
          service_instance_names << i.name unless i == @instance_to_unbind
        end

        @num_bindings_before = @app_obj.service_bindings.count

        req = Yajl::Encoder.encode(:services => service_instance_names)
        put "/apps/#{@app_obj.name}", req, headers_for(admin)
        @app_obj.refresh
        @bound_instances = @app_obj.service_bindings.map { |b| b.service_instance }
      end

      it "should return success" do
        last_response.status.should == 200
      end

      it "should add the the specified binding to the app" do
        @bound_instances.should include(@instance_to_bind)
      end

      it "should remove the specified binding from the app" do
        @bound_instances.should_not include(@instance_to_unbind)
      end
    end
  end
end
