require 'spec_helper'
require 'cloud_controller/diego/custom_stack_credential_resolver'

module VCAP::CloudController
  module Diego
    RSpec.describe CustomStackCredentialResolver do
      let(:stack_uri) { 'docker://registry.example.com/team/stack:latest' }
      let(:credentials_by_host) do
        { 'registry.example.com' => { 'username' => 'stack-user', 'password' => 'stack-pass' } }
      end

      subject(:image_credentials) { described_class.resolve(stack_uri:, credentials_by_host:) }

      it 'selects credentials for the stack registry' do
        expect(image_credentials).to eq(image_username: 'stack-user', image_password: 'stack-pass')
      end

      context 'with symbol keys' do
        let(:credentials_by_host) { { 'registry.example.com': { username: 'stack-user', password: 'stack-pass' } } }

        it 'accepts the credentials' do
          expect(image_credentials).to eq(image_username: 'stack-user', image_password: 'stack-pass')
        end
      end

      context 'with credentials for another registry' do
        let(:credentials_by_host) { { 'other.example.com' => { 'username' => 'other', 'password' => 'secret' } } }

        it 'does not forward them' do
          expect(image_credentials).to eq(image_username: nil, image_password: nil)
        end
      end

      context 'with an incomplete pair' do
        let(:credentials_by_host) { { 'registry.example.com' => { 'username' => 'stack-user' } } }

        it 'does not forward the partial pair' do
          expect(image_credentials).to eq(image_username: nil, image_password: nil)
        end
      end

      context 'without registry credentials' do
        let(:credentials_by_host) { nil }

        it 'uses no image credentials' do
          expect(image_credentials).to eq(image_username: nil, image_password: nil)
        end
      end

      context 'with a system stack' do
        let(:stack_uri) { 'cflinuxfs4' }

        it 'does not use registry credentials' do
          expect(image_credentials).to eq(image_username: nil, image_password: nil)
        end
      end
    end
  end
end
