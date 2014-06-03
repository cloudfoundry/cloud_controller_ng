require "spec_helper"

describe VCAP::CloudController::DatabaseUriGenerator do
  let(:service_uris) { ["postgres://username:password@host/db"] }
  let(:services) { VCAP::CloudController::DatabaseUriGenerator.new(service_uris) }

  describe "#database_uri" do
    subject(:database_uri) { services.database_uri }

    context "when there are relational database services" do
      context "and there uri is for mysql" do
        let(:service_uris) { ["mysql://username:password@host/db"] }

        it { should eq "mysql2://username:password@host/db" }
      end

      context "and there uri is for mysql2" do
        let(:service_uris) { ["mysql2://username:password@host/db"] }
        it { should eq "mysql2://username:password@host/db" }
      end

      context "and there uri is for postgres" do
        let(:service_uris) { ["postgres://username:password@host/db"] }
        it { should eq "postgres://username:password@host/db" }
      end

      context "and there uri is for postgresql" do
        let(:service_uris) { ["postgresql://username:password@host/db"] }
        it { should eq "postgres://username:password@host/db" }
      end

      context "and there are more than one production relational database" do
        let(:service_uris) do
          ["postgres://username:password@host/db1", "postgres://username:password@host/db2"]
        end

        it { should eq "postgres://username:password@host/db1" }
      end

      context "and the uri is invalid" do
        let(:service_uris) { ["postgresql:///inva\\:password@host/db"] }

        it { should be_nil }
      end
    end

    context "when there are non relational databse services" do
      let(:service_uris) { ["sendgrid://foo:bar@host/db"] }
      it { should be_nil }
    end

    context "when there are no services" do
      let(:service_uris) { nil }
      it { should be_nil }
    end
  end
end
