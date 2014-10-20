require 'spec_helper'
require 'handlers/process_handler'

module VCAP::CloudController
  describe ProcessHandler do
    describe "#find_by_guid" do
      it "find the process object by guid and returns a process" do
        process_model = ProcessModel.make
        process_handler = ProcessHandler.new
        process = process_handler.find_by_guid(process_model.guid)
        expect(process.guid).to eq(process_model.guid)
      end

      it "returns nil when the process does not exist" do
        process_handler = ProcessHandler.new
        process = process_handler.find_by_guid("non-existant-guid")
        expect(process).to be_nil
      end
    end
  end
end
