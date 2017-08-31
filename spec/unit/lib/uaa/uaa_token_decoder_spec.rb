require 'spec_helper'
require 'cloud_controller/uaa/uaa_token_decoder'

module VCAP::CloudController
  RSpec.describe UaaTokenDecoder do
    subject { UaaTokenDecoder.new(uaa_config) }

    let(:uaa_config) do
      {
        resource_id: 'resource-id',
        symmetric_secret: nil,
        url: 'http://localhost:8080/uaa',
        internal_url: 'https://uaa.service.cf.internal',
        ca_file: 'spec/fixtures/certs/uaa_ca.crt',
      }
    end

    let(:uaa_info) { double(CF::UAA::Info) }
    let(:uaa_client) { instance_double(VCAP::CloudController::UaaClient) }
    let(:logger) { double(Steno::Logger) }

    before do
      allow(::CloudController::DependencyLocator.instance).to receive(:uaa_client).and_return(uaa_client)
      allow(uaa_client).to receive(:info).and_return(uaa_info)
      allow(Steno).to receive(:logger).with('cc.uaa_token_decoder').and_return(logger)
      # undo global stubbing in spec_helper.rb
      allow_any_instance_of(VCAP::CloudController::UaaTokenDecoder).to receive(:uaa_issuer).and_call_original
    end

    describe '.new' do
      context 'when the decoder is created with a grace period' do
        context 'and that grace period is negative' do
          subject { UaaTokenDecoder.new(uaa_config, -10) }

          it 'logs a warning that the grace period was changed to 0' do
            expect(logger).to receive(:warn).with(/negative grace period interval.*-10.*is invalid, changed to 0/i)
            subject
          end
        end

        context 'and that grace period is not an integer' do
          subject { UaaTokenDecoder.new(uaa_config, 'blabla') }

          it 'raises an ArgumentError' do
            expect {
              subject
            }.to raise_error(ArgumentError, /grace period should be an integer/i)
          end
        end
      end
    end

    describe '#decode_token' do
      before do
        Timecop.freeze(Time.now.utc)
        stub_request(:get, uaa_issuer_info_url).to_return(body: { 'issuer' => uaa_issuer_string }.to_json)
      end
      after { Timecop.return }

      let(:uaa_issuer_string) { 'https://uaa.my-cf.com/uaa/stuff/here' }
      let(:uaa_issuer_info_url) { "#{VCAP::CloudController::Config.config.get(:uaa, :internal_url)}/.well-known/openid-configuration" }

      context 'when symmetric key is used' do
        before { uaa_config[:symmetric_secret] = 'symmetric-key' }

        context 'when token is valid' do
          let(:token_content) do
            {
              'aud'     => 'resource-id',
              'payload' => 123,
              'exp'     => Time.now.utc.to_i + 10_000,
              'iss'     => token_issuer_string,
            }
          end

          context 'when the token issuer matches the UAA' do
            let(:token_issuer_string) { uaa_issuer_string }

            it 'decodes the token' do
              token = CF::UAA::TokenCoder.encode(token_content, { skey: 'symmetric-key' })

              expect(subject.decode_token("bearer #{token}")).to eq(token_content)
            end

            it 'caches the issuer info from UAA' do
              token = CF::UAA::TokenCoder.encode(token_content, { skey: 'symmetric-key' })
              subject.decode_token("bearer #{token}")
              subject.decode_token("bearer #{token}")

              expect(WebMock).to have_requested(:get, uaa_issuer_info_url).once
            end
          end

          context "when the token issuer doesn't match the UAA" do
            let(:token_issuer_string) { 'https://totally.different.issuer/uaa' }

            it 'raises an exception' do
              token = CF::UAA::TokenCoder.encode(token_content, { skey: 'symmetric-key' })

              expect {
                subject.decode_token("bearer #{token}")
              }.to raise_error(UaaTokenDecoder::BadToken, 'Incorrect issuer')
            end
          end

          context 'when UAA responds with a non-200 while fetching the issuer' do
            let(:token_issuer_string) { uaa_issuer_string }

            context 'when the UAA responds with a 200 within 3 attempts' do
              before do
                stub_request(:get, uaa_issuer_info_url).
                  to_return(status: 404).then.
                  to_return(status: 404).then.
                  to_return(body: { 'issuer' => uaa_issuer_string }.to_json)
              end

              it 'eventually decodes the token' do
                token = CF::UAA::TokenCoder.encode(token_content, { skey: 'symmetric-key' })

                expect(subject.decode_token("bearer #{token}")).to eq(token_content)
              end
            end

            context "when the UAA doesn't return a 200 within 3 attempts" do
              before do
                stub_request(:get, uaa_issuer_info_url).to_return(status: 404)
              end

              it 'raises an error' do
                token = CF::UAA::TokenCoder.encode(token_content, { skey: 'symmetric-key' })
                expect {
                  subject.decode_token("bearer #{token}")
                }.to raise_error(/Could not retrieve issuer information from UAA/)
              end
            end
          end
        end

        context 'when token is invalid' do
          let(:token_content) { 'token' }

          it 'raises BadToken exception' do
            expect(logger).to receive(:warn).with(/invalid bearer token/i)

            expect {
              subject.decode_token("bearer #{token_content}")
            }.to raise_error(VCAP::CloudController::UaaTokenDecoder::BadToken)
          end
        end
      end

      context 'when asymmetric key is used' do
        before { uaa_config[:symmetric_secret] = nil }

        let(:rsa_key) { OpenSSL::PKey::RSA.new(2048) }
        before { allow(uaa_info).to receive_messages(validation_keys_hash: { 'key1' => { 'value' => rsa_key.public_key.to_pem } }) }

        context 'when token is valid' do
          let(:token_content) do
            {
              'aud'     => 'resource-id',
              'payload' => 123,
              'exp'     => Time.now.utc.to_i + 10_000,
              'iss'     => token_issuer_string,
            }
          end
          let(:token_issuer_string) { 'https://uaa.my-cf.com/uaa/stuff/here' }

          context 'when the token issuer matches the UAA' do
            let(:token_issuer_string) { uaa_issuer_string }

            it 'successfully decodes token and caches key' do
              token = generate_token(rsa_key, token_content)

              expect(uaa_info).to receive(:validation_keys_hash)
              expect(subject.decode_token("bearer #{token}")).to eq(token_content)

              expect(uaa_info).not_to receive(:validation_keys_hash)
              expect(subject.decode_token("bearer #{token}")).to eq(token_content)
            end

            describe 're-fetching key' do
              let(:old_rsa_key) { OpenSSL::PKey::RSA.new(2048) }

              it 'retries to decode token with newly fetched asymmetric key' do
                allow(uaa_info).to receive(:validation_keys_hash).and_return(
                  { 'old_key' => { 'value' => old_rsa_key.public_key.to_pem } },
                  { 'new_key' => { 'value' => rsa_key.public_key.to_pem } }
                )
                expect(subject.decode_token("bearer #{generate_token(rsa_key, token_content)}")).to eq(token_content)
              end

              it 'stops retrying to decode token with newly fetched asymmetric key after 1 try' do
                allow(uaa_info).to receive(:validation_keys_hash).and_return({ 'old_key' => { 'value' => old_rsa_key.public_key.to_pem } })

                expect(logger).to receive(:warn).with(/invalid bearer token/i)
                expect {
                  subject.decode_token("bearer #{generate_token(rsa_key, token_content)}")
                }.to raise_error(VCAP::CloudController::UaaTokenDecoder::BadToken)
              end
            end
          end

          context "when the token issuer doesn't match the UAA" do
            let(:token_issuer_string) { 'https://totally.different.issuer/uaa' }

            it 'raises an exception' do
              token = generate_token(rsa_key, token_content)

              expect {
                subject.decode_token("bearer #{token}")
              }.to raise_error(UaaTokenDecoder::BadToken, 'Incorrect issuer')
            end
          end

          context 'when UAA responds with a non-200 while fetching the issuer' do
            let(:token_issuer_string) { uaa_issuer_string }

            context 'when the UAA responds with a 200 within 3 attempts' do
              before do
                stub_request(:get, uaa_issuer_info_url).
                  to_return(status: 404).then.
                  to_return(status: 404).then.
                  to_return(body: { 'issuer' => uaa_issuer_string }.to_json)
              end

              it 'eventually decodes the token' do
                token = generate_token(rsa_key, token_content)

                expect(subject.decode_token("bearer #{token}")).to eq(token_content)
              end
            end

            context "when the UAA doesn't return a 200 within 3 attempts" do
              before do
                stub_request(:get, uaa_issuer_info_url).to_return(status: 404)
              end

              it 'raises an error' do
                token = generate_token(rsa_key, token_content)

                expect {
                  subject.decode_token("bearer #{token}")
                }.to raise_error(/Could not retrieve issuer information from UAA/)
              end
            end
          end
        end

        context 'when token has invalid audience' do
          let(:token_content) do
            {
              'aud'     => 'invalid-audience',
              'payload' => 123,
              'exp'     => Time.now.utc.to_i + 10_000,
              'iss'     => uaa_issuer_string,
            }
          end

          it 'raises an BadToken error' do
            expect(logger).to receive(:warn).with(/invalid bearer token/i)
            expect {
              subject.decode_token("bearer #{generate_token(rsa_key, token_content)}")
            }.to raise_error(VCAP::CloudController::UaaTokenDecoder::BadToken)
          end
        end

        context 'when token has expired' do
          let(:token_content) do
            { 'aud' => 'resource-id', 'payload' => 123, 'exp' => Time.now.utc.to_i }
          end

          it 'raises a BadToken error' do
            expect(logger).to receive(:warn).with(/token expired/i)
            expect {
              subject.decode_token("bearer #{generate_token(rsa_key, token_content)}")
            }.to raise_error(VCAP::CloudController::UaaTokenDecoder::BadToken)
          end
        end

        context 'when token is invalid' do
          it 'raises BadToken error' do
            expect(logger).to receive(:warn).with(/invalid bearer token/i)
            expect {
              subject.decode_token('bearer invalid-token')
            }.to raise_error(VCAP::CloudController::UaaTokenDecoder::BadToken)
          end
        end

        context 'when multiple asymmetric keys are used' do
          let(:bad_rsa_key) { OpenSSL::PKey::RSA.new(2048) }
          let(:token_content) do
            {
              'aud'     => 'resource-id',
              'payload' => 123,
              'exp'     => Time.now.utc.to_i + 10_000,
              'iss'     => uaa_issuer_string,
            }
          end

          it 'succeeds when it has first key that is valid' do
            allow(uaa_info).to receive(:validation_keys_hash).and_return({
              'new_key' => { 'value' => rsa_key.public_key.to_pem },
              'bad_key' => { 'value' => bad_rsa_key.public_key.to_pem } }
            )
            token = generate_token(rsa_key, token_content)

            expect(uaa_info).to receive(:validation_keys_hash)
            expect(subject.decode_token("bearer #{token}")).to eq(token_content)
          end

          it 'succeeds when subsequent key is valid' do
            allow(uaa_info).to receive(:validation_keys_hash).and_return({
              'bad_key' => { 'value' => bad_rsa_key.public_key.to_pem },
              'new_key' => { 'value' => rsa_key.public_key.to_pem } }
            )
            token = generate_token(rsa_key, token_content)

            expect(uaa_info).to receive(:validation_keys_hash)
            expect(subject.decode_token("bearer #{token}")).to eq(token_content)
          end

          it 're-fetches keys when none of the keys are valid' do
            other_bad_key = OpenSSL::PKey::RSA.new(2048)
            allow(uaa_info).to receive(:validation_keys_hash).and_return(
              {
                'bad_key'       => { 'value' => bad_rsa_key.public_key.to_pem },
                'other_bad_key' => { 'value' => other_bad_key.public_key.to_pem }
              },
              {
                're-fetched_key' => { 'value' => rsa_key.public_key.to_pem }
              }
            )
            token = generate_token(rsa_key, token_content)

            expect(uaa_info).to receive(:validation_keys_hash).twice
            expect(subject.decode_token("bearer #{token}")).to eq(token_content)
          end

          it 'fails when re-fetched keys are also not valid' do
            other_bad_key = OpenSSL::PKey::RSA.new(2048)
            final_bad_key = OpenSSL::PKey::RSA.new(2048)
            allow(uaa_info).to receive(:validation_keys_hash).and_return(
              {
                'bad_key'       => { 'value' => bad_rsa_key.public_key.to_pem },
                'other_bad_key' => { 'value' => other_bad_key.public_key.to_pem }
              },
              {
                'final_bad_key' => { 'value' => final_bad_key.public_key.to_pem }
              }
            )
            token = generate_token(rsa_key, token_content)

            expect(uaa_info).to receive(:validation_keys_hash).twice
            expect(logger).to receive(:warn).with(/invalid bearer token/i)
            expect {
              subject.decode_token("bearer #{token}")
            }.to raise_error(VCAP::CloudController::UaaTokenDecoder::BadToken)
          end
        end

        context 'when the decoder has an grace period specified' do
          subject { UaaTokenDecoder.new(uaa_config, 100) }
          let(:token_content) do
            { 'aud'     => 'resource-id',
              'payload' => 123,
              'exp'     => Time.now.utc.to_i,
              'iss'     => uaa_issuer_string,
            }
          end

          let(:token) { generate_token(rsa_key, token_content) }

          context 'and the token is currently expired but had not expired within the grace period' do
            it 'decodes the token and logs a warning about expiration within the grace period' do
              token_content['exp'] = Time.now.utc.to_i - 50
              expect(logger).to receive(:warn).with(/token currently expired but accepted within grace period of 100 seconds/i)
              expect(subject.decode_token("bearer #{token}")).to eq token_content
            end
          end

          context 'and the token expired outside of the grace period' do
            it 'raises and logs a warning about the expired token' do
              token_content['exp'] = Time.now.utc.to_i - 150
              expect(logger).to receive(:warn).with(/token expired/i)
              expect {
                subject.decode_token("bearer #{token}")
              }.to raise_error(VCAP::CloudController::UaaTokenDecoder::BadToken)
            end
          end

          context 'and that grace period interval is negative' do
            subject { UaaTokenDecoder.new(uaa_config, -10) }

            it 'sets the grace period to be 0 instead' do
              token_content['exp'] = Time.now.utc.to_i
              expired_token        = generate_token(rsa_key, token_content)
              allow(logger).to receive(:warn)
              expect {
                subject.decode_token("bearer #{expired_token}")
              }.to raise_error(VCAP::CloudController::UaaTokenDecoder::BadToken)

              token_content['exp'] = Time.now.utc.to_i + 1
              valid_token          = generate_token(rsa_key, token_content)
              expect(subject.decode_token("bearer #{valid_token}")).to eq token_content
            end
          end
        end

        def generate_token(rsa_key, content)
          CF::UAA::TokenCoder.encode(content, pkey: rsa_key, algorithm: 'RS256')
        end
      end
    end
  end
end
