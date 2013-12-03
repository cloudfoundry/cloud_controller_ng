require "spec_helper"

module VCAP::CloudController
  describe TasksController, type: :controller do
    describe "POST /v2/tasks" do
      context "when an app is given" do
        let!(:some_app) { AppFactory.make :guid => "some-app-guid" }

        context "and the app exists" do
          it "returns 201 Created" do
            post "/v2/tasks",
              '{"app_guid":"some-app-guid"}',
              json_headers(admin_headers)

            last_response.status.should == 201
          end

          it "creates the task" do
            expect {
              post "/v2/tasks",
                '{"app_guid":"some-app-guid"}',
                json_headers(admin_headers)

              response = Yajl::Parser.parse(last_response.body)
              guid = response["metadata"]["guid"]

              task = Task.find(:guid => guid)
              expect(task.app_guid).to eq("some-app-guid")
            }.to change {
              Task.all.size
            }.by(1)
          end

          context "when tasks endpoint is disabled" do
            before do
              config_override(:tasks_disabled => true)
            end
            it "returns 404" do
              post "/v2/tasks",
                '{"app_guid":"some-app-guid"}',
                json_headers(admin_headers)

              last_response.status.should == 404
            end
          end
        end

        context "and the app is not found" do
          before { some_app.destroy(savepoint: true) }

          it "returns HTTP status 400" do
            post "/v2/tasks",
              '{"app_guid":"some-bogus-app-guid"}',
              json_headers(admin_headers)

            last_response.status.should == 400
          end
        end
      end

      context "and an app is NOT given" do
        it "returns a 400-level error code" do
          post "/v2/tasks",
            '{}',
            json_headers(admin_headers)

          last_response.status.should == 400
        end
      end

      context "when a pubkey is NOT given" do
        it "returns a 400-level error code" do
          post "/v2/tasks",
            '{"app_guid":"some-app-guid"}',
            json_headers(admin_headers)

          last_response.status.should == 400
        end
      end
    end

    describe "GET /v2/tasks" do
      before do
        @user_a = User.make
        @user_b = User.make

        @org_a = Organization.make
        @org_b = Organization.make

        @space_a = Space.make :organization => @org_a
        @space_b = Space.make :organization => @org_b

        @org_a.add_user(@user_a)
        @org_b.add_user(@user_b)

        @space_a.add_developer(@user_a)
        @space_b.add_developer(@user_b)

        @app_a = AppFactory.make :space => @space_a
        @app_b = AppFactory.make :space => @space_b

        @task_a = Task.make :app => @app_a
        @task_b = Task.make :app => @app_b
      end

      it "includes only tasks from apps visible to the user" do
        get "/v2/tasks", {}, headers_for(@user_a)

        parsed_body = Yajl::Parser.parse(last_response.body)
        parsed_body["total_results"].should == 1
      end

      describe "GET /v2/tasks/:guid" do
        context "when the guid is valid" do
          context "and the task is visible to the user" do
            it "returns the correct task" do
              get "/v2/tasks/#{@task_a.guid}", {},
                headers_for(@user_a)

              last_response.status.should == 200

              parsed_body = Yajl::Parser.parse(last_response.body)
              expect(parsed_body["entity"]["app_guid"]).to eq(@task_a.app_guid)
            end

            context "when tasks endpoint is disabled" do
              before do
                config_override(:tasks_disabled => true)
              end
              it "returns 404" do
                get "/v2/tasks/#{@task_a.guid}", {},
                  headers_for(@user_a)

                last_response.status.should == 404
              end
            end
          end

          context "and the task is NOT visible to the user" do
            it "returns a 404 error" do
              get "/v2/tasks/#{@task_a.guid}", {},
                headers_for(@user_b)

              last_response.status.should == 403
            end
          end
        end

        context "when the guid is invalid" do
          it "returns a 404 error" do
            get "/v2/tasks/some-bogus-guid", {}, admin_headers

            last_response.status.should == 404
          end
        end
      end
    end

    describe "DELETE /v2/tasks/:guid" do
      before do
        @org = Organization.make
        @space = Space.make :organization => @org

        @admin = User.make :admin => true
        @org_manager = User.make
        @space_manager = User.make
        @space_developer = User.make
        @space_auditor = User.make

        [ @org_manager, @space_manager, @space_developer,
          @space_auditor
        ].each do |user|
          @org.add_user(user)
        end

        @org.add_manager(@org_manager)
        @space.add_manager(@space_manager)
        @space.add_developer(@space_developer)
        @space.add_auditor(@space_auditor)

        @app = AppFactory.make :space => @space
        @task = Task.make :app => @app
      end

      def self.it_returns_status_code(code)
        it "returns status code #{code}" do
          delete "/v2/tasks/#{@task.guid}", {}, headers

          last_response.status.should == code
        end
      end

      def self.it_deletes_the_task
        it "deletes the task" do
          expect {
            delete "/v2/tasks/#{@task.guid}", {}, headers
          }.to change {
            Task.find(:guid => @task.guid)
          }.to(nil)
        end
      end

      def self.it_does_not_delete_the_task
        it "does not delete the task" do
          expect {
            delete "/v2/tasks/#{@task.guid}", {}, headers
          }.to_not change {
            Task.count
          }.by(-1)
        end
      end

      context "if there is no user logged in" do
        let(:headers) { headers_for nil }
        it_returns_status_code 401
        it_does_not_delete_the_task
      end

      context "if the user is an admin" do
        let(:headers) { admin_headers }
        it_returns_status_code 204
        it_deletes_the_task
      end

      context "when tasks endpoint is disabled" do
        let(:headers) { admin_headers }
        before do
          config_override(:tasks_disabled => true)
        end
        it_returns_status_code 404
        it_does_not_delete_the_task
      end

      context "if the user is an Organization Manager" do
        let(:headers) { headers_for @org_manager }
        it_returns_status_code 403
        it_does_not_delete_the_task
      end

      context "if the user is a Space Manager" do
        let(:headers) { headers_for @space_manager }
        it_returns_status_code 403
        it_does_not_delete_the_task
      end

      context "if the user is a Space Developer" do
        let(:headers) { headers_for @space_developer }
        it_returns_status_code 204
        it_deletes_the_task
      end

      context "if the user is a Space Auditor" do
        let(:headers) { headers_for @space_auditor }
        it_returns_status_code 403
        it_does_not_delete_the_task
      end
    end

    describe "PUT /v2/tasks/:guid" do
      context "when tasks endpoint is disabled" do
        before { config_override(:tasks_disabled => true) }

        it "returns 404" do
          put "/v2/tasks/some-app-guid", '{"app_guid":"some-app-guid"}', json_headers(admin_headers)

          last_response.status.should == 404
        end
      end
    end
  end
end
