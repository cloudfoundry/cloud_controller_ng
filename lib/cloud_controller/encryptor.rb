require "securerandom"
require "openssl/cipher"
require "base64"

module VCAP::CloudController::Encryptor
  class << self
    ALGORITHM = "AES-128-CBC".freeze

    def generate_salt
      SecureRandom.hex(4).to_s
    end

    def encrypt(input, salt)
      return nil unless input
      Base64.strict_encode64(run_cipher(make_cipher.encrypt, input, salt))
    end

    def decrypt(encrypted_input, salt)
      return nil unless encrypted_input
      run_cipher(make_cipher.decrypt, Base64.decode64(encrypted_input), salt)
    end

    attr_accessor :db_encryption_key

    private
    def make_cipher
      OpenSSL::Cipher::Cipher.new(ALGORITHM)
    end

    def run_cipher(cipher, input, salt)
      cipher.pkcs5_keyivgen(db_encryption_key, salt)
      cipher.update(input).tap { |result| result << cipher.final }
    end
  end
end
