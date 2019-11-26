require 'spec_helper'
require 'decorators/include_route_domain_decorator'

module VCAP::CloudController
  RSpec.describe IncludeRouteDomainDecorator do
    subject(:decorator) { IncludeRouteDomainDecorator }
    let(:domain1) { SharedDomain.make(name: 'z-first-domain.example.com') }
    let(:domain2) { SharedDomain.make(name: 'a-second-domain.example.com') }
    let(:routes) { [Route.make(domain: domain1), Route.make(domain: domain2), Route.make(domain: domain1)] }

    it 'decorates the given hash with domains from routes in asciibetical order' do
      undecorated_hash = { i_am: 'tim' }
      hash = subject.decorate(undecorated_hash, routes)
      expect(hash[:i_am]).to eq('tim')
      expect(hash[:included][:domains]).to eq([Presenters::V3::DomainPresenter.new(domain2).to_hash, Presenters::V3::DomainPresenter.new(domain1).to_hash])
    end

    it 'does not overwrite other included fields' do
      undecorated_hash = { foo: 'bar', included: { favorite_fruits: ['tomato', 'cucumber'] } }
      hash = subject.decorate(undecorated_hash, routes)
      expect(hash[:foo]).to eq('bar')
      expect(hash[:included][:domains]).to match_array([Presenters::V3::DomainPresenter.new(domain1).to_hash, Presenters::V3::DomainPresenter.new(domain2).to_hash])
      expect(hash[:included][:favorite_fruits]).to match_array(['tomato', 'cucumber'])
    end

    describe '.match?' do
      it 'matches include arrays containing "domain"' do
        expect(decorator.match?(['potato', 'domain', 'turnip'])).to be true
      end

      it 'does not match other include arrays' do
        expect(decorator.match?(['vegetal', 'turnip'])).to be false
      end
    end
  end
end
