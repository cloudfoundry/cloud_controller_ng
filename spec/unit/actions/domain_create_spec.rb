require 'spec_helper'
require 'actions/domain_create'
require 'messages/domain_create_message'

module VCAP::CloudController
  RSpec.describe DomainCreate do
    subject { DomainCreate.new }

    let(:name) { 'example.com' }

    describe '#create' do
      context 'provided every valid field' do
        let(:internal) { true }

        let(:message) { DomainCreateMessage.new({
          name: name,
          internal: internal,
        })
        }

        it 'creates a domain with all the provided fields' do
          domain = nil

          expect {
            domain = subject.create(message: message)
          }.to change { Domain.count }.by(1)

          expect(domain.name).to eq(name)
          expect(domain.internal).to eq(internal)
          expect(domain.guid).to_not be_nil
        end
      end

      context 'provided minimal message' do
        let(:message) { DomainCreateMessage.new({ name: name }) }

        it 'creates a domain with default values' do
          domain = nil

          expect {
            domain = subject.create(message: message)
          }.to change { Domain.count }.by(1)

          expect(domain.name).to eq(name)
          expect(domain.internal).to eq(false)
          expect(domain.guid).to_not be_nil
        end
      end
    end
  end
end
