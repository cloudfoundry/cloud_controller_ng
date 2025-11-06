require 'spec_helper'
require 'cloud_controller/diego/ssh_key'

module VCAP::CloudController
  module Diego
    RSpec.describe SSHKey do
      let(:ssh_key) { SSHKey.new(1024) }

      describe '#authorized_key' do
        it 'returns an open ssh format authorized key' do
          expect(ssh_key.authorized_key).to match(/\Assh-rsa .{200,}\Z/)
        end

        it 'does not change' do
          key1    = ssh_key.authorized_key
          key2    = ssh_key.authorized_key
          expect(key1).to eq(key2)
        end

        it 'has no newlines and decodes to a valid blob matching the key' do
          ssh_key = VCAP::CloudController::Diego::SSHKey.new(1024)

          ak = ssh_key.authorized_key
          expect(ak).not_to include("\n")

          type, b64 = ak.split(' ', 2)
          expect(type).to eq('ssh-rsa')

          blob = Base64.strict_decode64(b64)
          blob_buffer = Net::SSH::Buffer.new(blob)
          blob_type = blob_buffer.read_string
          e = blob_buffer.read_bignum # public exponent
          n = blob_buffer.read_bignum # modulus
          expect(blob_type).to eq('ssh-rsa')

          pk = OpenSSL::PKey::RSA.new(ssh_key.private_key)
          expect(e).to eq(pk.e)
          expect(n).to eq(pk.n)
        end
      end

      describe '#private_key' do
        it 'returns an open ssh format private key' do
          expect(ssh_key.private_key).to start_with('-----BEGIN RSA PRIVATE KEY-----')
          expect(ssh_key.private_key).to end_with("-----END RSA PRIVATE KEY-----\n")
        end

        it 'does not change' do
          key1    = ssh_key.private_key
          key2    = ssh_key.private_key
          expect(key1).to eq(key2)
        end
      end

      describe '#fingerprint' do
        it 'returns an sha1 fingerprint' do
          expect(ssh_key.fingerprint).to match(/([0-9a-f]{2}:){19}[0-9a-f]{2}/)
        end

        it 'match digests over the authorized_key blob exactly' do
          ssh_key = VCAP::CloudController::Diego::SSHKey.new(1024)

          b64 = ssh_key.authorized_key.split(' ', 2).last
          blob = Base64.strict_decode64(b64)

          sha1 = OpenSSL::Digest::SHA1.digest(blob)
          sha1_colon = sha1.unpack('C*').map { |b| sprintf('%02x', b) }.join(':')
          expect(ssh_key.fingerprint).to eq(sha1_colon)

          sha256 = OpenSSL::Digest::SHA256.digest(blob)
          expect(ssh_key.sha256_fingerprint).to eq(Base64.strict_encode64(sha256))
        end
      end

      describe '#fingerprint 256' do
        it 'returns an sha256 fingerprint' do
          expect(ssh_key.sha256_fingerprint).to match(%r{[a-zA-Z0-9+/=]{44}})
        end
      end

      describe 'key generation' do
        it 'produces different keys for different instances' do
          a = VCAP::CloudController::Diego::SSHKey.new(1024)
          b = VCAP::CloudController::Diego::SSHKey.new(1024)

          expect(a.private_key).not_to eq(b.private_key)
          expect(a.authorized_key).not_to eq(b.authorized_key)
        end
      end
    end
  end
end
