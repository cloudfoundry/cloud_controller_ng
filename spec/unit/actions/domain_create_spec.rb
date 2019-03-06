require 'spec_helper'
require 'actions/domain_create'
require 'messages/domain_create_message'

module VCAP::CloudController
  RSpec.describe DomainCreate do
    let(:name) { 'example.com' }
    let(:internal) { true }

    let(:message) { DomainCreateMessage.new({
      name: name,
      internal: internal,
    })
    }

    describe '#create' do
      context 'provided valid info' do
        it 'creates a domain' do
          domain = nil

          expect {
            domain = DomainCreate.create(message: message)
          }.to change { Domain.count }.by(1)

          expect(domain.name).to eq(name)
          expect(domain.internal).to eq(internal)
          expect(domain.guid).to_not be_nil
        end
      end
    end
  end
end
