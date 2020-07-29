require 'presenters/v3/service_credential_binding_presenter'

module VCAP
  module CloudController
    RSpec.describe Presenters::V3::ServiceCredentialBindingPresenter do
      CredentialBinding = Struct.new(:guid, :type)

      it 'should include the id and the guid' do
        credential_binding = CredentialBinding.new('some-guid', 'some-type')

        presenter = described_class.new(credential_binding)

        expect(presenter.to_hash).to eql({ guid: 'some-guid', type: 'some-type' })
      end
    end
  end
end
