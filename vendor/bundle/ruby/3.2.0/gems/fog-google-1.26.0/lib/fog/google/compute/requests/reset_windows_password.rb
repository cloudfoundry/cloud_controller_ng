# Copyright 2015 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Changes:
# March 2020: Modified example found here:
# https://github.com/GoogleCloudPlatform/compute-image-windows/blob/master/examples/windows_auth_python_sample.py
# to enable fog-google to change windows passwords.

require "openssl"
require "base64"
require "json"

module Fog
  module Google
    class Compute
      class Mock
        def reset_windows_password(_server:, _user:)
          Fog::Mock.not_implemented
        end
      end

      class Real
        ##
        # Resets Windows passwords for users on Google's Windows based images.  Code based on Google provided example.
        #
        # @param instance [String] the name of the instance
        # @param zone [String] the name of the zone of the instance
        # @param user [String] the user whose password should be reset
        #
        # @return [String] new password
        #
        # @see https://cloud.google.com/compute/docs/instances/windows/automate-pw-generation
        def reset_windows_password(server:, user:)
          # Pull the e-mail address of user authenticated to API
          email = @compute.request_options.authorization.issuer

          # Create a new key
          key = OpenSSL::PKey::RSA.new(2048)
          modulus, exponent = get_modulus_exponent_in_base64(key)

          # Get Old Metadata
          old_metadata = server.metadata

          # Create JSON Object with needed information
          metadata_entry = get_json_string(user, modulus, exponent, email)

          # Create new metadata object
          new_metadata = update_windows_keys(old_metadata, metadata_entry)

          # Set metadata on instance
          server.set_metadata(new_metadata, false)

          # Get encrypted password from Serial Port 4 Output

          # If machine is booting for the first time, there appears to be a
          # delay before the password appears on the serial port.
          sleep(1) until server.ready?
          serial_port_output = server.serial_port_output(:port => 4)
          loop_cnt = 0
          while serial_port_output.empty?
            if loop_cnt > 12
              Fog::Logger.warning("Encrypted password never found on Serial Output Port 4")
              raise "Could not reset password."
            end
            sleep(5)
            serial_port_output = server.serial_port_output(:port => 4)
            loop_cnt += 1
          end

          # Parse and decrypt password
          enc_password = get_encrypted_password_from_serial_port(serial_port_output, modulus)
          password = decrypt_password(enc_password, key)

          return password
        end

        def get_modulus_exponent_in_base64(key)
          mod = [key.n.to_s(16)].pack("H*").strip
          exp = [key.e.to_s(16)].pack("H*").strip
          modulus = Base64.strict_encode64(mod).strip
          exponent = Base64.strict_encode64(exp).strip
          return modulus, exponent
        end

        def get_expiration_time_string
          utc_now = Time.now.utc
          expire_time = utc_now + 5 * 60
          return expire_time.strftime("%Y-%m-%dT%H:%M:%SZ")
        end

        def get_json_string(user, modulus, exponent, email)
          expire = get_expiration_time_string
          data = { 'userName': user,
                   'modulus': modulus,
                   'exponent': exponent,
                   'email': email,
                   'expireOn': expire }
          return ::JSON.dump(data)
        end

        def update_windows_keys(old_metadata, metadata_entry)
          if old_metadata[:items]
            new_metadata = Hash[old_metadata[:items].map { |item| [item[:key], item[:value]] }]
          else
            new_metadata = {}
          end
          new_metadata["windows-keys"] = metadata_entry
          return new_metadata
        end

        def get_encrypted_password_from_serial_port(serial_port_output, modulus)
          output = serial_port_output.split("\n")
          output.reverse_each do |line|
            begin
              if line.include?("modulus") && line.include?("encryptedPassword")
                entry = ::JSON.parse(line)
                if modulus == entry["modulus"]
                  return entry["encryptedPassword"]
                end
              else
                next
              end
            rescue ::JSON::ParserError
              Fog::Logger.warning("Parsing encrypted password from serial output
                                  failed. Trying to parse next matching line.")
              next
            end
          end
        end

        def decrypt_password(enc_password, key)
          decoded_password = Base64.strict_decode64(enc_password)
          begin
            return key.private_decrypt(decoded_password, OpenSSL::PKey::RSA::PKCS1_OAEP_PADDING)
          rescue OpenSSL::PKey::RSAError
            Fog::Logger.warning("Error decrypting password received from Google.
                                Maybe check output on Serial Port 4 and Metadata key: windows-keys?")
          end
        end
      end
    end
  end
end
