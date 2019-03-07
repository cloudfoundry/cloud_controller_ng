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

      context 'provided an overlapping domain name' do
        context 'with an existing domain' do
          let(:existing_domain) { SharedDomain.make }
          let(:message) { DomainCreateMessage.new({ name: existing_domain.name }) }

          it 'returns an error' do
            expect {
              subject.create(message: message)
            }.to raise_error(DomainCreate::Error, "The domain name \"#{existing_domain.name}\" is already reserved by another domain or route.")
          end
        end

        context 'with an existing scoped domain as a sub domain' do
          let(:private_domain) { PrivateDomain.make }
          let(:domain) { "sub.#{private_domain.name}" }
          let(:message) { DomainCreateMessage.new({ name: domain }) }

          it 'returns an error' do
            expect {
              subject.create(message: message)
            }.to raise_error(DomainCreate::Error, "The domain name \"#{domain}\" is already reserved by another domain or route.")
          end
        end

        context 'with an existing route' do
          let(:existing_domain) { SharedDomain.make }
          let(:route) { Route.make(domain: existing_domain) }
          let(:domain) { route.fqdn }
          let(:message) { DomainCreateMessage.new({ name: domain }) }

          it 'returns an error' do
            expect {
              subject.create(message: message)
            }.to raise_error(DomainCreate::Error, "The domain name \"#{domain}\" is already reserved by another domain or route.")
          end
        end
      end
    end
  end
end
