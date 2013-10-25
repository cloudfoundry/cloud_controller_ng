require "spec_helper"
require "stringio"

module VCAP::CloudController
  describe RestController::ModelController do
    let(:logger) { double('logger').as_null_object }
    subject(:controller) { controller_class.new({}, logger, {}, {}, request_body) }

    describe "#create" do
      let!(:model_table_name) { "model_class_#{SecureRandom.hex(10)}".to_sym }
      let!(:model_class) do
        db.create_table model_table_name do
          primary_key :id
          String :guid
          Date :created_at
          Date :updated_at
        end

        table_name = model_table_name
        Class.new(Sequel::Model) do
          set_dataset(db[table_name])
        end
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

    describe "#update" do
      let(:controller_class) { AppsController }
      let(:app) { AppFactory.make }
      let(:guid) { app.guid }

      let(:request_body) do
        StringIO.new({
          :state => "STOPPED"
        }.to_json)
      end

      before do
        subject.stub(:find_guid_and_validate_access).with(:update, guid) { app }
        SecurityContext.stub(:current_user).and_return(User.make)
      end

      it "prevents other processes from updating the same row until the transaction finishes" do
        app.should_receive(:lock!).ordered
        app.should_receive(:update_from_hash).ordered
        controller.update(guid)
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
