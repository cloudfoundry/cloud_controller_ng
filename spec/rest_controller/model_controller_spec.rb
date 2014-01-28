require "spec_helper"
require "stringio"

module VCAP::CloudController
  describe RestController::ModelController, non_transactional: true do
    let(:user) { User.make(admin: true, active: true) }
    let(:scope) { {'scope' => [VCAP::CloudController::Roles::CLOUD_CONTROLLER_ADMIN_SCOPE]} }
    let(:logger) { double('logger').as_null_object }
    let(:env) { {} }
    let(:params) { {} }
    let(:request_body) { StringIO.new('{}') }

    let!(:model_table_name) { :test_models }
    let!(:model_klass_name) { "TestModel" }
    let!(:model_klass) do
      db.create_table model_table_name do
        primary_key :id
        String :guid
        String :value
        Date :created_at
        Date :updated_at
      end

      define_model_class(model_klass_name, model_table_name)
    end

    let(:controller_class) do
      stub_const("VCAP::CloudController::#{model_klass_name}", model_klass)
      model_class_name_for_controller_context = model_klass_name

      Class.new(described_class) do
        model_class_name(model_class_name_for_controller_context)
        define_messages
      end.tap do |controller_class|
        stub_const("VCAP::CloudController::#{model_klass_name}Controller", controller_class)
      end
    end

    subject(:controller) { controller_class.new({}, logger, env, params, request_body) }

    def define_model_class(class_name, table_name)
      stub_const("VCAP::Errors::#{class_name}NotFound", Errors::AppPackageNotFound)
      stub_const("VCAP::CloudController::#{class_name}Access", BaseAccess)

      Class.new(Sequel::Model).tap do |klass|
        klass.define_singleton_method(:name) do
          "VCAP::CloudController::#{class_name}"
        end

        klass.set_dataset(db[table_name])

        unless VCAP::CloudController.const_defined?(class_name)
          VCAP::CloudController.const_set(class_name, klass)
        end
      end
    end

    before { VCAP::CloudController::SecurityContext.set(user, scope) }
    after { db.drop_table model_table_name }

    describe "#create" do
      it "raises InvalidRequest when a CreateMessage cannot be extracted from the request body" do
        controller_class::CreateMessage.any_instance.stub(:extract).and_return(nil)
        expect { controller.create }.to raise_error(VCAP::Errors::InvalidRequest)
      end

      it "calls the hooks in the right order" do
        controller_class::CreateMessage.any_instance.stub(:extract).and_return({extracted: "json"})

        controller.should_receive(:before_create).with(no_args).ordered
        model_klass.should_receive(:create_from_hash).with({extracted: "json"}).ordered.and_call_original
        controller.should_receive(:after_create).with(instance_of(model_klass)).ordered

        expect { controller.create }.to change { model_klass.count }.by(1)
      end

      context "when validate access fails" do
        before do
          controller.stub(:validate_access).and_raise(VCAP::Errors::NotAuthorized)

          controller.should_receive(:before_create).with(no_args).ordered
          model_klass.should_receive(:create_from_hash).ordered.and_call_original
          controller.should_not_receive(:after_create)
        end

        it "raises the validation failure" do
          expect { controller.create }.to raise_error(VCAP::Errors::NotAuthorized)
        end

        it "does not persist the model" do
          before_count = model_klass.count
          begin
            controller.create
          rescue VCAP::Errors::NotAuthorized
          end
          after_count = model_klass.count
          expect(after_count).to eq(before_count)
        end
      end

      it "returns the right values on a successful create" do
        result = controller.create
        model_instance = model_klass.first
        expect(model_instance.guid).not_to be_nil

        url = "/v2/test_model/#{model_instance.guid}"

        expect(result[0]).to eq(201)
        expect(result[1]).to eq({"Location" => url})

        parsed_json = JSON.parse(result[2])
        expect(parsed_json.keys).to match_array(%w(metadata entity))
      end

      it "should call the serialization instance asssociated with controller to generate response data" do
        serializer = double
        controller.should_receive(:serialization).and_return(serializer)
        serializer.should_receive(:render_json).with(controller_class, instance_of(model_klass), {}).and_return("serialized json")

        result = controller.create
        expect(result[2]).to eq("serialized json")
      end
    end

    describe "#read" do
      context "when the guid matches a record" do
        let!(:model) do
          instance = model_klass.new
          instance.save
          instance
        end

        it "raises if validate_access fails" do
          controller.stub(:validate_access).and_raise(VCAP::Errors::NotAuthorized)
          expect { controller.read(model.guid) }.to raise_error(VCAP::Errors::NotAuthorized)
        end

        it "returns the serialized object if access is validated" do
          serializer = double
          controller.should_receive(:serialization).and_return(serializer)
          serializer.should_receive(:render_json).with(controller_class, model, {}).and_return("serialized json")

          expect(controller.read(model.guid)).to eq("serialized json")
        end
      end

      context "when the guid does not match a record" do
        it "raises a not found exception for the underlying model" do
          error_class = Class.new(RuntimeError)
          stub_const("VCAP::CloudController::Errors::TestModelNotFound", error_class)
          expect { controller.read(SecureRandom.uuid) }.to raise_error(error_class)
        end
      end
    end

    describe "#update" do
      context "when the guid matches a record" do
        let!(:model) do
          instance = model_klass.new
          instance.save
          instance
        end

        let(:request_body) do
          StringIO.new({:state => "STOPPED"}.to_json)
        end

        it "raises if validate_access fails" do
          controller.stub(:validate_access).and_raise(VCAP::Errors::NotAuthorized)
          expect { controller.update(model.guid) }.to raise_error(VCAP::Errors::NotAuthorized)
        end

        it "prevents other processes from updating the same row until the transaction finishes" do
          model_klass.stub(:find).with(:guid => model.guid).and_return(model)
          model.should_receive(:lock!).ordered
          model.should_receive(:update_from_hash).ordered.and_call_original

          controller.update(model.guid)
        end

        it "returns the serialized updated object if access is validated" do
          serializer = double
          controller.should_receive(:serialization).and_return(serializer)
          serializer.should_receive(:render_json).with(controller_class, instance_of(model_klass), {}).and_return("serialized json")

          result = controller.update(model.guid)
          expect(result[0]).to eq(201)
          expect(result[1]).to eq("serialized json")
        end

        it "updates the data" do
          expect(model.updated_at).to be_nil

          controller.update(model.guid)

          model_from_db = model_klass.find(:guid => model.guid)
          expect(model_from_db.updated_at).not_to be_nil
        end

        it "calls the hooks in the right order" do
          model_klass.stub(:find).with(:guid => model.guid).and_return(model)

          controller.should_receive(:before_update).with(model).ordered
          model.should_receive(:update_from_hash).ordered.and_call_original
          controller.should_receive(:after_update).with(model).ordered

          controller.update(model.guid)
        end
      end
      context "when the guid does not match a record" do
        it "raises a not found exception for the underlying model" do
          error_class = Class.new(RuntimeError)
          stub_const("VCAP::CloudController::Errors::TestModelNotFound", error_class)
          expect { controller.update(SecureRandom.uuid) }.to raise_error(error_class)
        end
      end
    end

    describe "#do_delete" do
      let!(:model) { model_klass.create }

      shared_examples "tests with associations" do
        let!(:test_model_destroy_table_name) { :test_model_destroy_deps }
        let!(:test_model_destroy_dep_class) do
          create_dependency_class(test_model_destroy_table_name, "TestModelDestroyDep")
        end

        let!(:test_model_nullify_table_name) { :test_model_nullify_deps }
        let!(:test_model_nullify_dep_class) do
          create_dependency_class(test_model_nullify_table_name, "TestModelNullifyDep")
        end

        let(:test_model_nullify_dep) { VCAP::CloudController::TestModelNullifyDep.create() }

        let(:env) { {"PATH_INFO" => VCAP::CloudController::RestController::Base::ROUTE_PREFIX} }

        def create_dependency_class(table_name, class_name)
          db.create_table table_name do
            primary_key :id
            String :guid
            foreign_key :test_model_id, :test_models
          end

          define_model_class(class_name, table_name)
        end

        before do
          model_klass.one_to_many test_model_destroy_table_name
          model_klass.one_to_many test_model_nullify_table_name

          model_klass.add_association_dependencies(test_model_destroy_table_name => :destroy,
                                                   test_model_nullify_table_name => :nullify)

          model.add_test_model_destroy_dep VCAP::CloudController::TestModelDestroyDep.create()
          model.add_test_model_nullify_dep test_model_nullify_dep
        end

        after do
          db.drop_table test_model_destroy_table_name
          db.drop_table test_model_nullify_table_name
        end

        context "when deleting with recursive set to true" do
          let(:run_delayed_job) { Delayed::Worker.new.work_off if Delayed::Job.last }

          subject(:controller) { controller_class.new({}, logger, env, params.merge("recursive" => "true"), request_body) }

          it "successfully deletes" do
            expect {
              controller.do_delete(model)
              run_delayed_job
            }.to change {
              model_klass.count
            }.by(-1)
          end

          it "successfully deletes association marked for destroy" do
            expect {
              controller.do_delete(model)
              run_delayed_job
            }.to change {
              test_model_destroy_dep_class.count
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
            }.to raise_error(VCAP::Errors::AssociationNotEmpty)
          end
        end
      end

      context "when sync" do
        it "deletes the object" do
          expect {
            controller.do_delete(model)
          }.to change {
            model_klass.count
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

        it "enqueues a job to delete the object" do
          expect {
            expect { controller.do_delete(model) }.to_not change { model_klass.count }
          }.to change {
            Delayed::Job.count
          }.by(1)

          job = Delayed::Job.last
          expect(job.queue).to eq "cc-generic"
          expect(job.payload_object).to be_a Jobs::Runtime::ModelDeletion
          expect(job.payload_object.model_class).to eq model_klass
          expect(job.payload_object.guid).to eq model.guid
        end

        it "returns a 202 with the job information" do
          http_code, body = controller.do_delete(model)

          expect(http_code).to eq(202)
          expect(body).to include('"status": "queued"')
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

        controller_class.stub(path: fake_class_path)

        RestController::PaginatedCollectionRenderer.should_receive(:render_json).with(
          controller_class,
          filtered_dataset,
          fake_class_path,
          anything,
          params,
        )

        controller.enumerate
      end
    end

    describe "#find_guid_and_validate_access" do
      let!(:model) { model_klass.create }

      context "when a model exists" do
        context "and a find_model is supplied" do
          it "finds the model and grants access" do
            expect(controller.find_guid_and_validate_access(:read, model.guid, model_klass)).to eq(model)
          end
        end

        context "and a find_model is not supplied" do
          context "and access is authorized" do
            it "finds the model and grants access" do
              expect(controller.find_guid_and_validate_access(:read, model.guid)).to eq(model)
            end
          end

          context "and the user is not authenticated" do
            it "finds the model and does not grant access" do
              VCAP::CloudController::SecurityContext.set(nil)
              expect {
                controller.find_guid_and_validate_access(:read, model.guid)
              }.to raise_error Errors::NotAuthenticated
            end
          end

          context "and the user is not allowed access" do
            let(:scope) { {'scope' => []} }

            it "finds the model and does not grant access" do
              expect {
                controller.find_guid_and_validate_access(:read, model.guid)
              }.to raise_error Errors::NotAuthorized
            end
          end
        end
      end

      context "when a model does not exist" do
        context "and a find_model is supplied" do
          it "should raise Model Not Found" do
            expect {
              controller.find_guid_and_validate_access(:read, model.guid, App)
            }.to raise_error Errors::TestModelNotFound
          end
        end

        context "and a find_model is not supplied" do
          it "should raise Model Not Found" do
            expect {
              controller.find_guid_and_validate_access(:read, "bogus_guid")
            }.to raise_error Errors::TestModelNotFound
          end
        end
      end
    end
  end
end
