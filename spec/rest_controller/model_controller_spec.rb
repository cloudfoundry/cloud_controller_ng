require "stringio"

require File.expand_path("../../spec_helper", __FILE__)

module VCAP::CloudController
  describe RestController::ModelController do
    let(:logger) { double('logger').as_null_object }
    subject(:controller) { controller_class.new({}, logger, {}, {}, request_body) }

    describe "#update" do
      let(:controller_class) { App }
      let(:app) { Models::App.make }
      let(:guid) { app.guid }

      let(:request_body) do
        StringIO.new({
          :state => "STOPPED"
        }.to_json)
      end

      before do
        subject.stub(:find_guid_and_validate_access).with(:update, guid) { app }
      end

      it "prevent other processes from updating the same row until the transaction finishes" do
        app.should_receive(:lock!).ordered
        app.should_receive(:update_from_hash).ordered
        controller.update(guid)
      end
    end

    describe '#enumerate' do
      let!(:model_class) do
        reset_database
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
        stub_const("VCAP::CloudController::Models::#{klass_name}", model_class)
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
