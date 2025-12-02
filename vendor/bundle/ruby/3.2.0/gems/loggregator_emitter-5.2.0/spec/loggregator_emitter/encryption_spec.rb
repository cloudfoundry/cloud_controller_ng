# encoding: utf-8

require "spec_helper"
require "loggregator_emitter"

describe Encryption do
  subject(:crypter) { Encryption::Symmetric.new }
  it "pads" do
    key = "aaaaaaaaaaaaaaaa"
    message = "1234567890123456"
    encrypted = crypter.encrypt(key, message)
    val = encrypted.unpack("C*")
  end

  it "encrypts" do
    key = "aaaaaaaaaaaaaaaa"
    message = "Super secret message that no one should read"
    encrypted = crypter.encrypt(key, message)
    decrypted = crypter.decrypt(key, encrypted)

    expect(message).to eq decrypted
    expect(message).not_to eq encrypted
  end

  it "encrypts non-deterministicly" do
    key = "aaaaaaaaaaaaaaaa"
    message = "Super secret message that no one should read"
    encrypted1 = crypter.encrypt(key, message)
    encrypted2 = crypter.encrypt(key, message)

    expect(encrypted1).not_to eq encrypted2
  end

  it "encrypts with a short key" do
    key = "short key"
    message = "Super secret message that no one should read"
    encrypted = crypter.encrypt(key, message)
    decrypted = crypter.decrypt(key, encrypted)

    expect(message).to eq decrypted
    expect(message).not_to eq encrypted
  end

  it "does not decryption with wrong key" do
    key = "aaaaaaaaaaaaaaaa"
    message = "Super secret message that no one should read"
    encrypted = crypter.encrypt(key, message)

    expect {
      crypter.decrypt(key + "something went wrong", encrypted)
    }.to raise_exception(OpenSSL::Cipher::CipherError)
  end

  describe "compatibility with the encryption done in the Go library github.com/cloudfoundry/loggregatorlib/symmetric" do
    it "get_encryption_key generates the same key as the go version" do
      key = "12345"
      new_key = crypter.send(:get_encryption_key, key)

      expected_hex = [0x59, 0x94, 0x47, 0x1a, 0xbb, 0x1, 0x11, 0x2a, 0xfc, 0xc1, 0x81, 0x59, 0xf6, 0xcc, 0x74, 0xb4]

      expect(new_key.unpack("C*")).to eq expected_hex
    end

    it "computes digests the same way as the go version" do
      value = "some-key"

      expected_hex = [0x68, 0x2f, 0x66, 0x97, 0xfa, 0x93, 0xec, 0xa6, 0xc8, 0x1, 0xa2, 0x32, 0x51, 0x9a, 0x9, 0xe3, 0xfe, 0xc, 0x5c, 0x33, 0x94, 0x65, 0xee, 0x53, 0xc3, 0xf9, 0xed, 0xf9, 0x2f, 0xd0, 0x1f, 0x35]

      expect(crypter.digest(value).unpack("C*")).to eq expected_hex
    end
  end
end
