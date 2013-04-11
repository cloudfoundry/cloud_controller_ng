require "stringio"

require File.expand_path("../../spec_helper", __FILE__)

module VCAP::CloudController
  describe RestController::ModelController do
    let(:controller_class) { App }
    let(:logger_out) { StringIO.new }

    subject { controller_class.new({}, Logger.new(logger_out), {}, {}, request_body) }

    describe "#update" do
      let(:app) { Models::App.make }
      let(:guid) { app.guid }

      let(:request_body) do
        StringIO.new({
          :state => "STOPPED"
        }.to_json)
      end

      before do
        subject.stub(:find_id_and_validate_access).with(:update, guid) { app }
      end

      it "prevent other processes from updating the same row until the transaction finishes" do
        app.should_receive(:lock!).ordered
        app.should_receive(:update_from_hash).ordered
        subject.update(guid)
      end
    end
  end
end