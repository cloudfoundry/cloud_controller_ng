require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::ServiceAuthToken, type: :model do

    it_behaves_like "a model with an encrypted attribute" do
      let(:encrypted_attr) { :token }
    end

    it_behaves_like "a CloudController model", {
      :sensitive_attributes => :token,
      :extra_json_attributes => :token,
      :stripped_string_attributes => [:label, :provider]
    }

    describe "Validations" do
      it { should validate_presence :label }
      it { should validate_presence :provider }
      it { should validate_presence :token }
      it { should validate_uniqueness [:label, :provider] }
    end
  end
end
