require "spec_helper"

module VCAP::CloudController
  describe EnvironmentVariableGroup, type: :model do
    subject(:env_group) { EnvironmentVariableGroup.make(name: "something") }

    it { is_expected.to have_timestamp_columns }

    describe "Serialization" do
      it { is_expected.to export_attributes :name, :environment_json }
      it { is_expected.to import_attributes :environment_json }
    end

    describe "#staging" do
      context "when the corresponding db object does not exist" do
        it "creates a new database object with the right name" do
          expect(EnvironmentVariableGroup).to receive(:create).with(:name => "staging")
          EnvironmentVariableGroup.staging
        end

        it "initializes the object with an empty environment" do
          expect(EnvironmentVariableGroup.staging.environment_json).to eq({})
        end

        it "updates the object on save" do
          staging = EnvironmentVariableGroup.staging
          staging.environment_json = {"abc" => "easy as 123"}
          staging.save

          expect(EnvironmentVariableGroup.staging.environment_json).to eq({"abc" => "easy as 123"})
        end
      end

      context "when the corresponding db object exists" do
        it "returns the existing object" do
          EnvironmentVariableGroup.make(name: "staging", environment_json: {"abc" => 123})
          expect(EnvironmentVariableGroup.staging.environment_json).to eq("abc" => 123)
        end
      end
    end

    describe "#running" do
      context "when the corresponding db object does not exist" do
        it "creates a new database object with the right name" do
          expect(EnvironmentVariableGroup).to receive(:create).with(:name => "running")
          EnvironmentVariableGroup.running
        end

        it "initializes the object with an empty environment" do
          expect(EnvironmentVariableGroup.running.environment_json).to eq({})
        end

        it "updates the object on save" do
          running = EnvironmentVariableGroup.running
          running.environment_json = {"abc" => "easy as 123"}
          running.save

          expect(EnvironmentVariableGroup.running.environment_json).to eq({"abc" => "easy as 123"})
        end
      end

      context "when the corresponding db object exists" do
        it "returns the existing object" do
          EnvironmentVariableGroup.make(name: "running", environment_json: {"abc" => 123})
          expect(EnvironmentVariableGroup.running.environment_json).to eq("abc" => 123)
        end
      end
    end

    describe "environment_json is encrypted" do
      let(:env) { {"jesse" => "awesome"} }
      let(:long_env) { {"many_os" => "o" * 10_000} }
      let!(:var_group) { EnvironmentVariableGroup.make(environment_json: env, name: "test") }
      let(:last_row) { EnvironmentVariableGroup.dataset.naked.order_by(:id).last }

      it "is encrypted" do
        expect(last_row[:encrypted_environment_json]).not_to eq MultiJson.dump(env).to_s
      end

      it "is decrypted" do
        var_group.reload
        expect(var_group.environment_json).to eq env
      end

      it "salt is unique for each variable group" do
        var_group2 = EnvironmentVariableGroup.make(environment_json: env, name: "runtime2")
        expect(var_group.salt).not_to eq var_group2.salt
      end

      it "must have a salt of length 8" do
        expect(var_group.salt.length).to eq 8
      end

      it "works with long serialized environments" do
        var_group = EnvironmentVariableGroup.make(environment_json: long_env, name: "runtime2")
        var_group.reload
        expect(var_group.environment_json).to eq(long_env)
      end
    end
  end
end
