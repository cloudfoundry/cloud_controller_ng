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
    end
  end
end
