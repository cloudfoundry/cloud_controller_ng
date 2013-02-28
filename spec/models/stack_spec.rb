# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController::Models
  describe Stack do
    it_behaves_like "a CloudController model", {
      :required_attributes        => [:name, :description],
      :unique_attributes          => :name,
      :stripped_string_attributes => :name,
    }

    describe ".populate_from_file" do
      context "when stacks file is valid" do
        before { reset_database }
        let(:file) { File.expand_path("../../fixtures/config/stacks.yml", __FILE__) }

        it "loads stacks" do
          described_class.populate_from_file(file)
          cider = described_class.find(:name => "cider")
          cider.should be_valid
        end

        it "populates descriptions about loaded stacks" do
          described_class.populate_from_file(file)
          cider = described_class.find(:name => "cider")
          cider.description.should == "cider-description"
        end
      end

      context "when stacks file is invalid" do
        let(:file) { File.expand_path("../../fixtures/config/invalid_stacks.yml", __FILE__) }

        it "raises error" do
          expect {
            described_class.populate_from_file(file)
          }.to raise_error(Membrane::SchemaValidationError, /name => Missing key/)
        end
      end

      describe "config/stacks.yml" do
        let(:file) { File.expand_path("../../../config/stacks.yml", __FILE__) }

        it "can load" do
          described_class.populate_from_file(file)
        end
      end
    end
  end
end
