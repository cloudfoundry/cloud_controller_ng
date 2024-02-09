require 'spec_helper'
require 'decorators/include_binding_app_decorator'

module VCAP::CloudController
  RSpec.describe IncludeBindingAppDecorator do
    subject(:decorator) { IncludeBindingAppDecorator }
    let(:service_credential_bindings) { ServiceCredentialBinding::View.dataset.all }

    context 'service bindings' do
      let!(:bindings) { [ServiceBinding.make, ServiceBinding.make, ServiceBinding.make] }
      let(:apps) do
        bindings.map { |b| Presenters::V3::AppPresenter.new(b.app).to_hash }
      end

      it 'decorates the given hash with apps from bindings' do
        dict = { foo: 'bar' }
        hash = subject.decorate(dict, service_credential_bindings)
        expect(hash[:foo]).to eq('bar')
        expect(hash[:included][:apps]).to match_array(apps)
      end

      it 'does not overwrite other included fields' do
        dict = { foo: 'bar', included: { fruits: %w[tomato banana] } }
        hash = subject.decorate(dict, service_credential_bindings)
        expect(hash[:foo]).to eq('bar')
        expect(hash[:included][:apps]).to match_array(apps)
        expect(hash[:included][:fruits]).to match_array(%w[tomato banana])
      end
    end

    context 'service keys' do
      let!(:keys) { [ServiceKey.make] }

      it 'does not query the database' do
        expect do
          subject.decorate({}, service_credential_bindings)
        end.to have_queried_db_times(/select \* from .apps. where/i, 0)
      end
    end

    describe '.match?' do
      it 'matches include arrays containing "app"' do
        expect(decorator).to be_match(%w[potato app turnip])
      end

      it 'does not match other include arrays' do
        expect(decorator).not_to be_match(%w[potato turnip])
      end
    end
  end
end
