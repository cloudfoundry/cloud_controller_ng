require 'spec_helper'
require 'cloud_controller/diego/ssh_key'

module VCAP::CloudController
  module Diego
    RSpec.describe SSHKey do
      describe '#authorized_key' do
        it 'returns an open ssh format authorized key' do
          ssh_key = SSHKey.new(1024)
          expect(ssh_key.authorized_key).to match(/\Assh-rsa .{200,}\Z/)
        end

        it 'does not change' do
          ssh_key = SSHKey.new(1024)
          key1    = ssh_key.authorized_key
          key2    = ssh_key.authorized_key
          expect(key1).to eq(key2)
        end
      end

      describe '#private_key' do
        it 'returns an open ssh format private key' do
          ssh_key = SSHKey.new(1024)
          expect(ssh_key.private_key).to start_with('-----BEGIN RSA PRIVATE KEY-----')
          expect(ssh_key.private_key).to end_with("-----END RSA PRIVATE KEY-----\n")
        end

        it 'does not change' do
          ssh_key = SSHKey.new(1024)
          key1    = ssh_key.private_key
          key2    = ssh_key.private_key
          expect(key1).to eq(key2)
        end
      end

      describe '#fingerprint' do
        it 'returns an sha1 fingerprint' do
          ssh_key = SSHKey.new(1024)
          expect(ssh_key.fingerprint).to match(/([0-9a-f]{2}:){19}[0-9a-f]{2}/)
        end
      end

      describe '#fingerprint 256' do
        it 'returns an sha256 fingerprint' do
          ssh_key = SSHKey.new(1024)
          expect(ssh_key.sha256_fingerprint).to match(/[a-zA-Z0-9+\/=]{44}/)
        end
      end
    end
  end
end
