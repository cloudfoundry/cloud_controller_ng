# coding: US-ASCII
require 'digest/sha1'
require 'openssl'

module Encryption
  class Symmetric
    AES_BLOCKSIZE = 16

    def encrypt(key, message)
      cipher = OpenSSL::Cipher::AES128.new(:CBC)
      cipher.encrypt
      cipher.key = get_encryption_key(key)
      cipher.padding = 0
      iv = cipher.random_iv

      iv + cipher.update(pad_buffer(message)) + cipher.final
    end

    def decrypt(key, encrypted)
      cipher = OpenSSL::Cipher::AES128.new(:CBC)
      cipher.padding = 0
      cipher.decrypt
      cipher.key = get_encryption_key(key)
      cipher.iv = encrypted[0..AES_BLOCKSIZE-1]

      unpad_buffer(cipher.update(encrypted[AES_BLOCKSIZE..encrypted.length]) + cipher.final)
    end

    def digest(value)
      Digest::SHA256.digest(value)
    end

    private

    def get_encryption_key(key)
      digest(key)[0..AES_BLOCKSIZE-1]
    end

    def pad_buffer(message)
      bytes_to_pad = AES_BLOCKSIZE - message.length % AES_BLOCKSIZE

      message + "\x80" + "\x00" * (bytes_to_pad - 1)
    end

    def unpad_buffer(message)
      raise OpenSSL::Cipher::CipherError unless message.match(/\x80\x00*$/)

      message.gsub(/\x80\x00*$/, '')
    end
  end
end

