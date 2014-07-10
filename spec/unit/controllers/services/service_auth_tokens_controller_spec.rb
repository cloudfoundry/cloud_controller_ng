require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::ServiceAuthTokensController, :services do

    describe "Query Parameters" do
      it { expect(described_class).to be_queryable_by(:label) }
      it { expect(described_class).to be_queryable_by(:provider) }
    end

    describe "Attributes" do
      it do
        expect(described_class).to have_creatable_attributes({
          label: {type: "string", required: true},
          provider: {type: "string", required: true},
          token: {type: "string", required: true}
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
          label: {type: "string"},
          provider: {type: "string"},
          token: {type: "string"}
        })
      end
    end

    describe 'deprecation warning' do
      it 'adds the X-Cf-Warning to all endpoint responses' do
        get '/v2/service_auth_tokens', {}, admin_headers
        expect(last_response.status).to eq 200
        expect(last_response).to be_a_deprecated_response
      end
    end
  end
end
