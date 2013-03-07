# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController::Models
  describe Stack do
    it_behaves_like "a CloudController model", {
      :required_attributes        => [:name, :description],
      :unique_attributes          => :name,
      :stripped_string_attributes => :name,
    }

    describe ".configure" do
      context "with valid config" do
        let(:file) { File.expand_path("../../fixtures/config/stacks.yml", __FILE__) }

        it "can load" do
          described_class.configure(file)
        end
      end

      context "with invalid config" do
        let(:file) { File.expand_path("../../fixtures/config/invalid_stacks.yml", __FILE__) }

        {:default => "default => Missing key",
         :stacks => "name => Missing key"
        }.each do |key, expected_error|
          it "requires #{key} (validates via '#{expected_error}')" do
            expect {
              described_class.configure(file)
            }.to raise_error(Membrane::SchemaValidationError, /#{expected_error}/)
          end
        end
      end

      describe "config/stacks.yml" do
        let(:file) { File.expand_path("../../../config/stacks.yml", __FILE__) }

        it "can load" do
          described_class.configure(file)
        end
      end
    end

    describe ".populate_from_file" do
      context "when config was not set" do
        before { described_class.configure(nil) }

        it "raises config not specified error" do
          expect {
            described_class.default
          }.to raise_error(described_class::MissingConfigFileError)
        end
      end

      context "when config was set" do
        let(:file) { File.expand_path("../../fixtures/config/stacks.yml", __FILE__) }

        before do
          reset_database
          described_class.configure(file)
        end

        it "loads stacks" do
          described_class.populate
          cider = described_class.find(:name => "cider")
          cider.should be_valid
        end

        it "populates descriptions about loaded stacks" do
          described_class.populate
          cider = described_class.find(:name => "cider")
          cider.description.should == "cider-description"
        end
      end
    end

    describe ".default" do
      let(:file) { File.expand_path("../../fixtures/config/stacks.yml", __FILE__) }
      before { described_class.configure(file) }

      context "when config was not set" do
        before { described_class.configure(nil) }

        it "raises config not specified error" do
          expect {
            described_class.default
          }.to raise_error(described_class::MissingConfigFileError)
        end
      end

      context "when config was set" do
        before { reset_database }

        context "when stack is found with default name" do
          before { Stack.make(:name => "default-stack-name") }

          it "returns found stack" do
            described_class.default.name.should == "default-stack-name"
          end
        end

        context "when stack is not found with default name" do
          it "raises MissingDefaultStack" do
            expect {
              described_class.default
            }.to raise_error(described_class::MissingDefaultStackError, /default-stack-name/)
          end
        end
      end
    end
  end
end
