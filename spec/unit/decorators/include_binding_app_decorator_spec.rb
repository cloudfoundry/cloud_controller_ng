require 'spec_helper'
require 'decorators/include_binding_app_decorator'

module VCAP::CloudController
  RSpec.describe IncludeBindingAppDecorator do
    subject(:decorator) { IncludeBindingAppDecorator }
    let(:bindings) { [ServiceBinding.make, ServiceBinding.make, ServiceBinding.make] }
    let(:apps) {
      bindings.map { |b| Presenters::V3::AppPresenter.new(b.app).to_hash }
    }

    it 'decorates the given hash with apps from bindings' do
      dict = { foo: 'bar' }
      hash = subject.decorate(dict, bindings)
      expect(hash[:foo]).to eq('bar')
      expect(hash[:included][:apps]).to match_array(apps)
    end

    it 'does not overwrite other included fields' do
      dict = { foo: 'bar', included: { fruits: ['tomato', 'banana'] } }
      hash = subject.decorate(dict, bindings)
      expect(hash[:foo]).to eq('bar')
      expect(hash[:included][:apps]).to match_array(apps)
      expect(hash[:included][:fruits]).to match_array(['tomato', 'banana'])
    end

    describe '.match?' do
      it 'matches include arrays containing "app"' do
        expect(decorator.match?(['potato', 'app', 'turnip'])).to be_truthy
      end

      it 'does not match other include arrays' do
        expect(decorator.match?(['potato', 'turnip'])).to be_falsey
      end
    end
  end
end
