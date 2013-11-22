require "spec_helper"
require "stringio"

module VCAP::CloudController
  describe RestController::ModelController do
    let(:logger) { double('logger').as_null_object }
    let(:env) { {} }
    let(:params) { {} }

    subject(:controller) { controller_class.new({}, logger, env, params, request_body) }

    context "with a valid controller and underlying model", non_transactional: true do
      let!(:model_table_name) { :test_models }
      let!(:model_class) do
        db.create_table model_table_name do
          primary_key :id
          String :guid
          Date :created_at
          Date :updated_at
        end

        define_class("TestModel", model_table_name)
      end

      def define_class(class_name, table_name)
        klass = Class.new(Sequel::Model)
        klass.define_singleton_method(:name) do
          "VCAP::CloudController::#{class_name}"
        end

        klass.set_dataset(db[table_name])
        unless VCAP::CloudController.const_defined?(class_name)
          VCAP::CloudController.const_set(class_name, klass)
        end

        klass
      end

      after do
        db.drop_table model_table_name
      end

      let(:controller_class) do
        klass_name = 'TestModel'
        stub_const("VCAP::CloudController::#{klass_name}", model_class)
        klass = Class.new(described_class) do
          model_class_name(klass_name)
          define_messages

          def validate_access(*args)
            true
          end
        end
        stub_const("VCAP::CloudController::#{klass_name}Controller", klass)
        klass
      end

      let(:request_body) { StringIO.new('{}') }

      describe "#create" do
        it "raises InvalidRequest when a CreateMessage cannot be extracted from the request body" do
          controller_class::CreateMessage.any_instance.stub(:extract).and_return(nil)
          expect { controller.create }.to raise_error(VCAP::Errors::InvalidRequest)
        end

        it "calls the hooks in the right order" do
          controller_class::CreateMessage.any_instance.stub(:extract).and_return({extracted: "json"})

          controller.should_receive(:before_create).with(no_args).ordered
          model_class.should_receive(:create_from_hash).with({extracted: "json"}).ordered.and_call_original
          controller.should_receive(:after_create).with(instance_of(model_class)).ordered

          expect { controller.create }.to change { model_class.count }.by(1)
        end

        context "when validate access fails" do
          before do
            controller.stub(:validate_access).and_raise(VCAP::Errors::NotAuthorized)

            controller.should_receive(:before_create).with(no_args).ordered
            model_class.should_receive(:create_from_hash).ordered.and_call_original
            controller.should_not_receive(:after_create)
          end

          it "raises the validation failure" do
            expect{controller.create}.to raise_error(VCAP::Errors::NotAuthorized)
          end

          it "does not persist the model" do
            before_count = model_class.count
            begin
              controller.create
            rescue VCAP::Errors::NotAuthorized
            end
            after_count = model_class.count
            expect(after_count).to eq(before_count)
          end
        end

        it "returns the right values on a successful create" do
          result = controller.create
          model_instance = model_class.first
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
          serializer.should_receive(:render_json).with(controller_class, instance_of(model_class), {}).and_return("serialized json")

          result = controller.create
          expect(result[2]).to eq("serialized json")
        end
      end

      describe "#read" do
        context "when the guid matches a record" do
          let!(:model) do
            instance = model_class.new
            instance.save
            instance
          end

          it "raises if validate_access fails" do
            controller.stub(:validate_access).and_raise(VCAP::Errors::NotAuthorized)
            expect{controller.read(model.guid)}.to raise_error(VCAP::Errors::NotAuthorized)
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
            instance = model_class.new
            instance.save
            instance
          end

          let(:request_body) do
            StringIO.new({:state => "STOPPED"}.to_json)
          end

          it "raises if validate_access fails" do
            controller.stub(:validate_access).and_raise(VCAP::Errors::NotAuthorized)
            expect{controller.update(model.guid)}.to raise_error(VCAP::Errors::NotAuthorized)
          end

          it "prevents other processes from updating the same row until the transaction finishes" do
            model_class.stub(:find).with(:guid => model.guid).and_return(model)
            model.should_receive(:lock!).ordered
            model.should_receive(:update_from_hash).ordered.and_call_original

            controller.update(model.guid)
          end

          it "returns the serialized updated object if access is validated" do
            serializer = double
            controller.should_receive(:serialization).and_return(serializer)
            serializer.should_receive(:render_json).with(controller_class, instance_of(model_class), {}).and_return("serialized json")

            result = controller.update(model.guid)
            expect(result[0]).to eq(201)
            expect(result[1]).to eq("serialized json")
          end

          it "updates the data" do
            expect(model.updated_at).to be_nil

            controller.update(model.guid)

            model_from_db = model_class.find(:guid => model.guid)
            expect(model_from_db.updated_at).not_to be_nil
          end

          it "calls the hooks in the right order" do
            model_class.stub(:find).with(:guid => model.guid).and_return(model)

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

      describe "#delete" do
        let!(:model) { model_class.create }

        context "when the guid matches a record" do
          context "when validate_accesss fails" do
            before do
              controller.stub(:validate_access).and_raise(VCAP::Errors::NotAuthorized)
            end

            it "raises" do
              expect{controller.delete(model.guid)}.to raise_error(VCAP::Errors::NotAuthorized)
            end

            it "does not call the hooks" do
              controller.should_not_receive(:before_destroy)
              controller.should_not_receive(:after_destroy)

              begin
                controller.delete(model.guid)
              rescue VCAP::Errors::NotAuthorized
              end
            end
          end

          it "deletes the object if access if validated" do
            expect { controller.delete(model.guid) }.to change { model_class.count }.by(-1)
          end

          context "when the model has active associations" do
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

              define_class(class_name, table_name)
            end

            before do
              model_class.one_to_many test_model_destroy_table_name
              model_class.one_to_many test_model_nullify_table_name

              model_class.add_association_dependencies test_model_destroy_table_name => :destroy,
                                                       test_model_nullify_table_name => :nullify

              model.add_test_model_destroy_dep VCAP::CloudController::TestModelDestroyDep.create()
              model.add_test_model_nullify_dep test_model_nullify_dep
            end

            after do
              db.drop_table test_model_destroy_table_name
              db.drop_table test_model_nullify_table_name
            end

            context "when deleting with recursive set to true" do
              let(:params) { {"recursive" => "true"} }
              it "successfully deletes" do
                expect{controller.delete(model.guid)}.to change { model_class.count }.by(-1)
              end

              it "successfully deletes association marked for destroy" do
                expect{controller.delete(model.guid)}.to change { test_model_destroy_dep_class.count }.by(-1)
              end

              it "successfully nullifies association marked for nullify" do
                expect do
                  controller.delete(model.guid)
                  test_model_nullify_dep.reload
                end.to change { test_model_nullify_dep.test_model_id }.from(model.id).to(nil)
              end
            end

            context "when deleting non-recursively" do
              it "raises an association error" do
                expect{controller.delete(model.guid)}.to raise_error(VCAP::Errors::AssociationNotEmpty)
              end

              it "does not call any hooks" do
                controller.should_not_receive(:before_destroy)
                controller.should_not_receive(:after_destroy)

                begin
                  controller.delete(model.guid)
                rescue VCAP::Errors::AssociationNotEmpty
                end
              end
            end
          end

          it "calls the hooks in the right order" do
            model_class.stub(:find).with(:guid => model.guid).and_return(model)

            controller.should_receive(:before_destroy).with(model).ordered
            model.should_receive(:destroy).ordered.and_call_original
            controller.should_receive(:after_destroy).with(model).ordered

            controller.delete(model.guid)
          end

          it "returns a valid http response" do
            result = controller.delete(model.guid)

            expect(result[0]).to eq(204)
            expect(result[1]).to be_nil
          end
        end

        context "when the guid does not match a record" do
          it "raises a not found exception for the underlying model" do
            error_class = Class.new(RuntimeError)
            stub_const("VCAP::CloudController::Errors::TestModelNotFound", error_class)
            expect { controller.delete(SecureRandom.uuid) }.to raise_error(error_class)
          end
        end

      end
    end

    describe '#enumerate', non_transactional: true do
      let!(:model_class) do
        db.create_table :test do
          primary_key :id
          String :value
        end

        Class.new(Sequel::Model) do
          set_dataset(db[:test])
        end
      end

      let(:controller_class) do
        klass_name = 'TestModel%02x' % rand(16)
        stub_const("VCAP::CloudController::#{klass_name}", model_class)
        Class.new(described_class) do
          model_class_name(klass_name)
        end
      end

      before(:each) do
        VCAP::CloudController::SecurityContext.stub(current_user: double('current user', admin?: false))
      end

      let(:request_body) { StringIO.new('') }

      it 'paginates the dataset with query params' do
        fake_class_path = double('class path')
        filtered_dataset = double('dataset for enumeration', sql: 'SELECT *')
        Query.stub(filtered_dataset_from_query_params: filtered_dataset)
        controller_class.stub(path: fake_class_path)
        RestController::Paginator.should_receive(:render_json).with(
          controller_class,
          filtered_dataset,
          fake_class_path,
          # FIXME: we actually care about params...
          anything,
        )
        controller.enumerate
      end
    end
  end
end
