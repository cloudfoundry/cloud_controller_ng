require 'spec_helper'
require 'handlers/process_handler'

module VCAP::CloudController
  describe ProcessHandler do
    let(:valid_opts) do
      {
        name: "my-process",
        memory: 256,
        instances: 2,
        disk_quota: 1024,
        space_guid: Space.make.guid,
        stack_guid: Stack.make.guid
      }
    end
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

    describe "#new" do
      it "returns a process domain object that has not been persisted" do
          process_handler = ProcessHandler.new
          expect {
            process = process_handler.new(valid_opts)
            expect(process.guid).to be(nil)
          }.to_not change { ProcessModel.count }
      end
    end

    describe "#persist!" do
      context "when the desired process does not exist" do
        context "with a valid desired process" do
          it "persists the process data model" do
            process_handler = ProcessHandler.new
            expect {
              desired_process = process_handler.new(valid_opts)
              process = process_handler.persist!(desired_process)
              expect(process.guid).to_not be(nil)
            }.to change { ProcessModel.count }.by(1)
          end
        end
      end

      context "when the desired process is not valid" do
        it "raises a InvalidProcess error" do
          invalid_opts = {
            name: "my-process",
          }
          process_handler = ProcessHandler.new
          expect {
            expect {
              desired_process = process_handler.new(invalid_opts)
              process_handler.persist!(desired_process)
            }.to_not change { ProcessModel.count }
          }.to raise_error(ProcessHandler::InvalidProcess)
        end
      end
    end

    describe "delete" do
      context "when the process is persisted" do
        it "deletes the persisted process" do
          process_handler = ProcessHandler.new
          process = process_handler.persist!(process_handler.new(valid_opts))
          expect {
            process_handler.delete(process)
          }.to change { ProcessModel.count }.by(-1)
          expect(process_handler.find_by_guid(process.guid)).to be_nil
        end
      end

      context "when the process is not persisted" do
        it "does nothing" do
          process_handler = ProcessHandler.new
          process = process_handler.new(valid_opts)
          expect {
            process_handler.delete(process)
          }.to_not change { ProcessModel.count }
          expect(process_handler.find_by_guid(process.guid)).to be_nil
        end
      end
    end
  end
end
