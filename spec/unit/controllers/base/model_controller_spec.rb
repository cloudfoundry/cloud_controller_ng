require "spec_helper"
require "stringio"

module VCAP::CloudController
  class TestModelsController < RestController::ModelController
    define_attributes do
      attribute :required_attr, TrueClass
      attribute :unique_value, String
    end
    define_messages
    define_routes

    def delete(guid)
      do_delete(find_guid_and_validate_access(:delete, guid))
    end

    def self.translate_validation_exception(e, attributes)
      Errors::ApiError.new_from_details("TestModelValidation", attributes["unique_value"])
    end
  end

  describe RestController::ModelController do
    let(:user) { User.make(admin: true, active: true) }
    let(:scope) { {'scope' => [VCAP::CloudController::Roles::CLOUD_CONTROLLER_ADMIN_SCOPE]} }
    let(:logger) { double('logger').as_null_object }
    let(:params) { {} }
    let(:request_body) { StringIO.new('{}') }

    let!(:model_table_name) { :test_models }
    let!(:model_klass_name) { "TestModel" }

    subject(:controller) { TestModelsController.new({}, logger, env, params, request_body, sinatra, dependencies) }

    let(:sinatra) { double('sinatra') }
    let(:dependencies) { {object_renderer: object_renderer, collection_renderer: collection_renderer} }
    let(:object_renderer) { double('object_renderer', render_json: nil) }
    let(:collection_renderer) { double('collection_renderer', render_json: nil) }
    let(:test_model_nullify_dep) { TestModelNullifyDep.create }
    let(:env) { {"PATH_INFO" => RestController::BaseController::ROUTE_PREFIX} }
    let(:details) do
      double(VCAP::Errors::Details,
             name: "TestModelNotFound",
             response_code: 404,
             code: 12345,
             message_format: "Test model could not be found.")
    end

    before { SecurityContext.set(user, scope) }

    describe "common model controller behavior" do
      before do
        get "/v2/test_models", {}, headers
      end

      context "for an existing user" do
        let(:headers) do
          headers_for(VCAP::CloudController::User.make)
        end

        it "succeeds" do
          last_response.status.should == 200
        end
      end

      context "for a new user" do
        let(:headers) do
          headers_for(Machinist.with_save_nerfed { VCAP::CloudController::User.make })
        end

        it "succeeds" do
          last_response.status.should == 200
        end
      end

      context "for a deleted user" do
        let(:headers) do
          user = VCAP::CloudController::User.make
          headers = headers_for(user)
          user.delete
          headers
        end

        it "returns 200 by recreating the user" do
          last_response.status.should == 200
        end
      end

      context "for an admin" do
        let(:headers) do
          admin_headers
        end

        it "succeeds" do
          last_response.status.should == 200
        end
      end

      context "for no user" do
        let(:headers) do
          headers_for(nil)
        end

        it "should return 401" do
          last_response.status.should == 401
        end
      end
    end

    describe "#create" do
      it "raises InvalidRequest when a CreateMessage cannot be extracted from the request body" do
        TestModelsController::CreateMessage.any_instance.stub(:extract).and_return(nil)
        post "/v2/test_models", Yajl::Encoder.encode({required_attr: true, unique_value: "foobar"}), headers_for(user)
        expect(decoded_response['code']).to eq(10004)
        expect(decoded_response['description']).to match(/request is invalid/)
      end

      it "calls the hooks in the right order" do
        TestModelsController::CreateMessage.any_instance.stub(:extract).and_return({extracted: "json"})
        step = 0

        TestModelsController.any_instance.should_receive(:before_create).with(no_args) do
          expect(step).to eq(0)
          step += 1
        end
        TestModel.should_receive(:create_from_hash).with({extracted: "json"}) {
          expect(step).to eq(1)
          step += 1
          TestModel.make
        }
        TestModelsController.any_instance.should_receive(:after_create).with(instance_of(TestModel)) do
          expect(step).to eq(2)
        end

        post "/v2/test_models", Yajl::Encoder.encode({required_attr: true, unique_value: "foobar"}), headers_for(user)
      end

      context "when the user's token is missing the required scope" do
        let(:mock_access) { double(:access) }

        before do
          allow(BaseAccess).to receive(:new).and_return(mock_access)
          allow(mock_access).to receive(:cannot?).with(:create_with_token, anything).and_return(true)
        end

        it 'responds with a 403 Insufficient Scope' do
          post "/v2/test_models", Yajl::Encoder.encode({required_attr: true, unique_value: "foobar"}), headers_for(user)
          expect(decoded_response["code"]).to eq(10007)
          expect(decoded_response["description"]).to match(/lacks the necessary scopes/)
        end
      end

      context "when validate access fails" do
        before do
          TestModelsController.any_instance.stub(:validate_access).and_raise(VCAP::Errors::ApiError.new_from_details("NotAuthorized"))
        end

        it "does not persist the model" do
          expect {
            post "/v2/test_models", Yajl::Encoder.encode({required_attr: true, unique_value: "foobar"}), headers_for(user)
          }.to_not change { TestModel.count }

          expect(decoded_response["code"]).to eq(10003)
          expect(decoded_response["description"]).to match(/not authorized/)
        end
      end

      it "returns the right values on a successful create" do
        post "/v2/test_models", Yajl::Encoder.encode({required_attr: true, unique_value: "foobar"}), headers_for(user)
        model_instance = TestModel.first
        url = "/v2/test_models/#{model_instance.guid}"

        expect(last_response.status).to eq(201)
        expect(decoded_response["metadata"]["url"]).to eq(url)
      end
    end

    describe "#read" do
      context "when the guid matches a record" do
        let!(:model) { TestModel.make }

        it "raises if validate_access fails" do
          controller.stub(:validate_access).and_raise(VCAP::Errors::ApiError.new_from_details("NotAuthorized"))
          expect { controller.read(model.guid) }.to raise_error(VCAP::Errors::ApiError, "You are not authorized to perform the requested action")
        end

        it "returns the serialized object if access is validated" do
          object_renderer.
              should_receive(:render_json).
              with(TestModelsController, model, {}).
              and_return("serialized json")

          expect(controller.read(model.guid)).to eq("serialized json")
        end
      end

      context "when the guid does not match a record" do
        before do
          allow(VCAP::Errors::Details).to receive("new").with("TestModelNotFound").and_return(details)
        end

        it "raises a not found exception for the underlying model" do
          expect { controller.read(SecureRandom.uuid) }.to raise_error(VCAP::Errors::ApiError, /Test model could not be found/)
        end
      end
    end

    describe "#update" do
      context "when the guid matches a record" do
        let!(:model) { TestModel.make }

        let(:request_body) do
          StringIO.new({:state => "STOPPED"}.to_json)
        end

        it "raises if validate_access fails" do
          controller.stub(:validate_access).and_raise(VCAP::Errors::ApiError.new_from_details("NotAuthorized"))
          expect { controller.update(model.guid) }.to raise_error(VCAP::Errors::ApiError, /not authorized/)
        end

        it "prevents other processes from updating the same row until the transaction finishes" do
          TestModel.stub(:find).with(:guid => model.guid).and_return(model)
          model.should_receive(:lock!).ordered
          model.should_receive(:update_from_hash).ordered.and_call_original

          controller.update(model.guid)
        end

        it "returns the serialized updated object if access is validated" do
          object_renderer.
              should_receive(:render_json).
              with(TestModelsController, instance_of(TestModel), {}).
              and_return("serialized json")

          result = controller.update(model.guid)
          expect(result[0]).to eq(201)
          expect(result[1]).to eq("serialized json")
        end

        it "updates the data" do
          expect(model.updated_at).to be_nil

          controller.update(model.guid)

          model_from_db = TestModel.find(:guid => model.guid)
          expect(model_from_db.updated_at).not_to be_nil
        end

        it "calls the hooks in the right order" do
          TestModel.stub(:find).with(:guid => model.guid).and_return(model)

          controller.should_receive(:before_update).with(model).ordered
          model.should_receive(:update_from_hash).ordered.and_call_original
          controller.should_receive(:after_update).with(model).ordered

          controller.update(model.guid)
        end
      end

      context "when the guid does not match a record" do
        before do
          allow(VCAP::Errors::Details).to receive("new").with("TestModelNotFound").and_return(details)
        end

        it "raises a not found exception for the underlying model" do
          expect { controller.update(SecureRandom.uuid) }.to raise_error(VCAP::Errors::ApiError, /Test model could not be found/)
        end
      end
    end

    describe "#do_delete" do
      let!(:model) { TestModel.make }

      shared_examples "tests with associations" do
        before do
          model.add_test_model_destroy_dep TestModelDestroyDep.create
          model.add_test_model_nullify_dep test_model_nullify_dep
        end

        context "when deleting with recursive set to true" do
          let(:run_delayed_job) { Delayed::Worker.new.work_off if Delayed::Job.last }

          before { params.merge!("recursive" => "true") }

          it "successfully deletes" do
            expect {
              controller.do_delete(model)
              run_delayed_job
            }.to change {
              TestModel.count
            }.by(-1)
          end

          it "successfully deletes association marked for destroy" do
            expect {
              controller.do_delete(model)
              run_delayed_job
            }.to change {
              TestModelDestroyDep.count
            }.by(-1)
          end

          it "successfully nullifies association marked for nullify" do
            expect {
              controller.do_delete(model)
              run_delayed_job
            }.to change {
              test_model_nullify_dep.reload.test_model_id
            }.from(model.id).to(nil)
          end
        end

        context "when deleting non-recursively" do
          it "raises an association error" do
            expect {
              controller.do_delete(model)
            }.to raise_error(VCAP::Errors::ApiError, /associations/)
          end
        end
      end

      context "when sync" do
        it "deletes the object" do
          expect {
            controller.do_delete(model)
          }.to change {
            TestModel.count
          }.by(-1)
        end

        it "returns a 204" do
          http_code, body = controller.do_delete(model)

          expect(http_code).to eq(204)
          expect(body).to be_nil
        end

        context "when the model has active associations" do
          include_examples "tests with associations"
        end
      end

      context "when async" do
        let(:params) { {"async" => "true"} }

        context "and using the job enqueuer" do
          let(:job) { double(Jobs::Runtime::ModelDeletion) }
          let(:enqueuer) { double(Jobs::Enqueuer) }
          let(:presenter) { double(JobPresenter) }

          before do
            allow(Jobs::Runtime::ModelDeletion).to receive(:new).with(TestModel, model.guid).and_return(job)
            allow(Jobs::Enqueuer).to receive(:new).with(job, queue: "cc-generic").and_return(enqueuer)
            allow(enqueuer).to receive(:enqueue)

            allow(JobPresenter).to receive(:new).and_return(presenter)
            allow(presenter).to receive(:to_json)
          end

          it "enqueues a job to delete the object" do
            expect { controller.do_delete(model) }.to_not change { TestModel.count }

            expect(Jobs::Runtime::ModelDeletion).to have_received(:new).with(TestModel, model.guid)
            expect(Jobs::Enqueuer).to have_received(:new).with(job, queue: "cc-generic")
            expect(enqueuer).to have_received(:enqueue)
          end

          it "returns a 202 with the job information" do
            http_code, body = controller.do_delete(model)

            expect(http_code).to eq(202)
            expect(JobPresenter).to have_received(:new)
            expect(presenter).to have_received(:to_json)
          end
        end

        context "when the model has active associations" do
          include_examples "tests with associations"
        end
      end
    end

    describe "#enumerate" do
      let(:request_body) { StringIO.new('') }

      before do
        VCAP::CloudController::SecurityContext.stub(current_user: double('current user', admin?: false))
      end

      it "paginates the dataset with query params" do
        filtered_dataset = double("dataset for enumeration", sql: "SELECT *")
        fake_class_path = double("class path")

        Query.stub(filtered_dataset_from_query_params: filtered_dataset)

        TestModelsController.stub(path: fake_class_path)

        collection_renderer.should_receive(:render_json).with(
            TestModelsController,
            filtered_dataset,
            fake_class_path,
            anything,
            params,
        )

        controller.enumerate
      end
    end

    describe "#find_guid_and_validate_access" do
      let!(:model) { TestModel.make }

      context "when a model exists" do
        context "and a find_model is supplied" do
          it "finds the model and grants access" do
            expect(controller.find_guid_and_validate_access(:read, model.guid, TestModel)).to eq(model)
          end
        end

        context "and a find_model is not supplied" do
          context "and access is authorized" do
            it "finds the model and grants access" do
              expect(controller.find_guid_and_validate_access(:read, model.guid)).to eq(model)
            end
          end

          context "and the user does not have the authorization" do
            let(:scope) { {'scope' => ['cloud_controller.read', 'cloud_controller.write']} }

            before do
              dataset = double(:dataset)
              allow(dataset).to receive(:where).with(:guid => model.guid).and_return([])
              allow(model.class).to receive(:user_visible).with(user, false).and_return(dataset)
            end

            it "finds the model and does not grant access" do
              expect {
                controller.find_guid_and_validate_access(:read, model.guid)
              }.to raise_error Errors::ApiError, /not authorized/
            end
          end

          context "and the user does not have the necessary scopes" do
            let(:scope) { {'scope' => []} }

            it "finds the model and does not grant access" do
              expect {
                controller.find_guid_and_validate_access(:read, model.guid)
              }.to raise_error Errors::ApiError, /lacks the necessary scopes/
            end
          end
        end
      end

      context "when a model does not exist" do
        before do
          allow(VCAP::Errors::Details).to receive("new").with("TestModelNotFound").and_return(details)
        end

        context "and a find_model is supplied" do
          it "should raise Model Not Found" do
            expect {
              controller.find_guid_and_validate_access(:read, model.guid, App)
            }.to raise_error(Errors::ApiError, /could not be found/)
          end
        end

        context "and a find_model is not supplied" do
          it "should raise Model Not Found" do
            expect {
              controller.find_guid_and_validate_access(:read, "bogus_guid")
            }.to raise_error(Errors::ApiError, /could not be found/)
          end
        end
      end
    end

    describe "error handling" do
      describe "404" do
        before do
          VCAP::Errors::Details::HARD_CODED_DETAILS["TestModelNotFound"] = {
            'code' => 999999999,
            'http_code' => 404,
            'message' => "Test Model Not Found",
          }
        end

        it "returns not found for reads" do
          get "/v2/test_models/99999", {}, headers_for(user)
          expect(last_response.status).to eq(404)
          decoded_response["code"].should eq 999999999
          decoded_response["description"].should match(/Test Model Not Found/)
        end

        it "returns not found for updates" do
          put "/v2/test_models/99999", {}, headers_for(user)
          expect(last_response.status).to eq(404)
          decoded_response["code"].should eq 999999999
          decoded_response["description"].should match(/Test Model Not Found/)
        end

        it "returns not found for deletes" do
          delete "/v2/test_models/99999", {}, headers_for(user)
          expect(last_response.status).to eq(404)
          decoded_response["code"].should eq 999999999
          decoded_response["description"].should match(/Test Model Not Found/)
        end
      end

      describe "model errors" do
        before do
          VCAP::Errors::Details::HARD_CODED_DETAILS["TestModelValidation"] = {
            'code' => 999999998,
            'http_code' => 400,
            'message' => "Validation Error",
          }
        end

        it "returns 400 error for missing attributes; returns a request-id and no location" do
          post "/v2/test_models", "{}", headers_for(user)
          expect(last_response.status).to eq(400)
          decoded_response["code"].should eq 1001
          decoded_response["description"].should match(/invalid/)
          last_response.location.should be_nil
          last_response.headers["X-VCAP-Request-ID"].should_not be_nil
        end

        it "returns 400 error when validation fails on create" do
          TestModel.make(unique_value: 'unique')
          post "/v2/test_models", Yajl::Encoder.encode({required_attr: true, unique_value: 'unique'}), headers_for(user)
          expect(last_response.status).to eq(400)
          decoded_response["code"].should eq 999999998
          decoded_response["description"].should match(/Validation Error/)
        end

        it "returns 400 error when validation fails on update" do
          TestModel.make(unique_value: 'unique')
          test_model = TestModel.make(unique_value: 'not-unique')
          put "/v2/test_models/#{test_model.guid}", Yajl::Encoder.encode({unique_value: 'unique'}), headers_for(user)
          expect(last_response.status).to eq(400)
          decoded_response["code"].should eq 999999998
          decoded_response["description"].should match(/Validation Error/)
        end
      end

      describe "auth errors" do
        context "with invalid auth header" do
          let(:headers) do
            headers = headers_for(VCAP::CloudController::User.make)
            headers["HTTP_AUTHORIZATION"] += "EXTRA STUFF"
            headers
          end

          it "returns an error" do
            get "/v2/test_models", {}, headers
            expect(last_response.status).to eq 401
            expect(decoded_response["code"]).to eq 1000
            decoded_response["description"].should match(/Invalid Auth Token/)
          end
        end
      end
    end
  end
end
