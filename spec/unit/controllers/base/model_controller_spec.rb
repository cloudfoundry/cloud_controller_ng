require "spec_helper"
require "stringio"

module VCAP::CloudController
  class TestModelsController < RestController::ModelController
    define_messages
    define_routes
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

      context "with invalid auth header" do
        let(:headers) do
          headers = headers_for(VCAP::CloudController::User.make)
          headers["HTTP_AUTHORIZATION"] += "EXTRA STUFF"
          headers
        end

        it "returns an error" do
          expect(last_response.status).to eq 401
          expect(decoded_response["code"]).to eq 1000
        end

        it_behaves_like "a vcap rest error response", /Invalid Auth Token/
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
          headers_for(nil, admin_scope: true)
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
        expect { controller.create }.to raise_error(VCAP::Errors::ApiError, /The request is invalid/)
      end

      it "calls the hooks in the right order" do
        TestModelsController::CreateMessage.any_instance.stub(:extract).and_return({extracted: "json"})

        controller.should_receive(:before_create).with(no_args).ordered
        TestModel.should_receive(:create_from_hash).with({extracted: "json"}).ordered.and_call_original
        controller.should_receive(:after_create).with(instance_of(TestModel)).ordered

        expect { controller.create }.to change { TestModel.count }.by(1)
      end

      context "when the user's token is missing the required scope" do
        let(:mock_access) { double(:access) }

        before do
          allow(BaseAccess).to receive(:new).and_return(mock_access)
          allow(mock_access).to receive(:cannot?).with(:create_with_token, anything).and_return(true)
        end

        it 'responds with a 403 Insufficient Scope' do
          expect { controller.create }.to raise_error(VCAP::Errors::ApiError, /lacks the necessary scopes/)
        end
      end

      context "when validate access fails" do
        before do
          controller.stub(:validate_access).and_raise(VCAP::Errors::ApiError.new_from_details("NotAuthorized"))

          controller.should_receive(:before_create).with(no_args).ordered
          TestModel.should_receive(:create_from_hash).ordered.and_call_original
          controller.should_not_receive(:after_create)
        end

        it "raises the validation failure" do
          expect { controller.create }.to raise_error(VCAP::Errors::ApiError, /not authorized/)
        end

        it "does not persist the model" do
          before_count = TestModel.count
          begin
            controller.create
          rescue VCAP::Errors::ApiError
          end
          after_count = TestModel.count
          expect(after_count).to eq(before_count)
        end
      end

      it "returns the right values on a successful create" do
        result = controller.create
        model_instance = TestModel.first
        expect(model_instance.guid).not_to be_nil

        url = "/v2/test_models/#{model_instance.guid}"

        expect(result[0]).to eq(201)
        expect(result[1]).to eq({"Location" => url})
      end

      it "should call the serialization instance asssociated with controller to generate response data" do
        object_renderer.
            should_receive(:render_json).
            with(TestModelsController, instance_of(TestModel), {}).
            and_return("serialized json")

        result = controller.create
        expect(result[2]).to eq("serialized json")
      end
    end

    describe "#read" do
      context "when the guid matches a record" do
        let!(:model) do
          instance = TestModel.new
          instance.save
          instance
        end

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
        let!(:model) do
          instance = TestModel.new
          instance.save
          instance
        end

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
      let!(:model) { TestModel.create }

      shared_examples "tests with associations" do
        before do
          TestModel.one_to_many :test_model_destroy_deps
          TestModel.one_to_many :test_model_nullify_deps

          TestModel.add_association_dependencies(:test_model_destroy_deps => :destroy,
                                                 :test_model_nullify_deps => :nullify)

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
      let!(:model) { TestModel.create }

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
  end
end
