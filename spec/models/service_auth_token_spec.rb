require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Models::ServiceAuthToken do

    it_behaves_like "a model with an encrypted attribute" do
      let(:encrypted_attr) { :token }
    end

    it_behaves_like "a CloudController model", {
      :required_attributes  => [:label, :provider, :token],
      :unique_attributes    => [ [:label, :provider] ],
      :sensitive_attributes => :token,
      :extra_json_attributes => :token,
      :stripped_string_attributes => [:label, :provider]
    }
  end
end
