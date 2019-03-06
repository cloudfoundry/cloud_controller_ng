require 'spec_helper'
require 'presenters/v3/domain_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe DomainPresenter do
    let(:domain) do
      VCAP::CloudController::SharedDomain.make(
        name: 'my.domain.com',
        internal: true,
      )
    end

    describe '#to_hash' do
      it 'presents the domain as json' do
        result = DomainPresenter.new(domain).to_hash
        expect(result[:guid]).to eq(domain.guid)
        expect(result[:created_at]).to be_a(Time)
        expect(result[:updated_at]).to be_a(Time)
        expect(result[:name]).to eq(domain.name)
        expect(result[:internal]).to eq(domain.internal)
        expect(result[:links][:self][:href]).to eq("#{link_prefix}/v3/domains/#{domain.guid}")
      end
    end
  end
end
