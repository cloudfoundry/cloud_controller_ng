require 'spec_helper'
require 'vcap/uaa_token_decoder'

module VCAP
  RSpec.describe UaaTokenDecoder do
    subject { described_class.new(config_hash) }

    let(:config_hash) do
      { uaa: {
        resource_id: 'resource-id',
        symmetric_secret: nil
      },
        skip_cert_verify: true
      }
    end

    let(:uaa_info) { double(CF::UAA::Info) }
    let(:logger) { double(Steno::Logger) }

    before do
      allow(CF::UAA::Info).to receive(:new).and_return(uaa_info)
      allow(Steno).to receive(:logger).with('cc.uaa_token_decoder').and_return(logger)
    end

    describe '.new' do
      context 'when the decoder is created with a grace period' do
        context 'and that grace period is negative' do
          subject { described_class.new(config_hash, -10) }

          it 'logs a warning that the grace period was changed to 0' do
            expect(logger).to receive(:warn).with(/negative grace period interval.*-10.*is invalid, changed to 0/i)
            subject
          end
        end

        context 'and that grace period is not an integer' do
          subject { described_class.new(config_hash, 'blabla') }

          it 'raises an ArgumentError' do
            expect {
              subject
            }.to raise_error(ArgumentError, /grace period should be an integer/i)
          end
        end
      end
    end

    describe '#decode_token' do
      before { Timecop.freeze(Time.now.utc) }
      after { Timecop.return }

      context 'when symmetric key is used' do
        let(:token_content) do
          { 'aud' => 'resource-id', 'payload' => 123, 'exp' => Time.now.utc.to_i + 10_000 }
        end

        before { config_hash[:uaa][:symmetric_secret] = 'symmetric-key' }

        context 'when token is valid' do
          it 'uses UAA::TokenCoder to decode the token with skey' do
            token = CF::UAA::TokenCoder.encode(token_content, { skey: 'symmetric-key' })

            expect(subject.decode_token("bearer #{token}")).to eq(token_content)
          end
        end

        context 'when token is invalid' do
          it 'raises BadToken exception' do
            expect(logger).to receive(:warn).with(/invalid bearer token/i)

            expect {
              subject.decode_token('bearer token')
            }.to raise_error(VCAP::UaaTokenDecoder::BadToken)
          end
        end
      end

      context 'when asymmetric key is used' do
        before { config_hash[:uaa][:symmetric_secret] = nil }

        let(:rsa_key) { OpenSSL::PKey::RSA.new(2048) }
        before { allow(uaa_info).to receive_messages(validation_keys_hash: { 'key1' => { 'value' => rsa_key.public_key.to_pem } }) }

        context 'when token is valid' do
          let(:token_content) do
            { 'aud' => 'resource-id', 'payload' => 123, 'exp' => Time.now.utc.to_i + 10_000 }
          end

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
              }.to raise_error(VCAP::UaaTokenDecoder::BadToken)
            end
          end
        end

        context 'when token has invalid audience' do
          let(:token_content) do
            { 'aud' => 'invalid-audience', 'payload' => 123, 'exp' => Time.now.utc.to_i + 10_000 }
          end

          it 'raises an BadToken error' do
            expect(logger).to receive(:warn).with(/invalid bearer token/i)
            expect {
              subject.decode_token("bearer #{generate_token(rsa_key, token_content)}")
            }.to raise_error(VCAP::UaaTokenDecoder::BadToken)
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
            }.to raise_error(VCAP::UaaTokenDecoder::BadToken)
          end
        end

        context 'when token is invalid' do
          it 'raises BadToken error' do
            expect(logger).to receive(:warn).with(/invalid bearer token/i)
            expect {
              subject.decode_token('bearer invalid-token')
            }.to raise_error(VCAP::UaaTokenDecoder::BadToken)
          end
        end

        context 'when multiple asymmetric keys are used' do
          let(:bad_rsa_key) { OpenSSL::PKey::RSA.new(2048) }
          let(:token_content) do
            { 'aud' => 'resource-id', 'payload' => 123, 'exp' => Time.now.utc.to_i + 10_000 }
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
                'bad_key' => { 'value' => bad_rsa_key.public_key.to_pem },
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
            other_bad_key =  OpenSSL::PKey::RSA.new(2048)
            final_bad_key =  OpenSSL::PKey::RSA.new(2048)
            allow(uaa_info).to receive(:validation_keys_hash).and_return(
              {
                'bad_key' => { 'value' => bad_rsa_key.public_key.to_pem },
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
            }.to raise_error(VCAP::UaaTokenDecoder::BadToken)
          end
        end

        context 'when the decoder has an grace period specified' do
          subject { described_class.new(config_hash, 100) }

          let(:token_content) do
            { 'aud' => 'resource-id', 'payload' => 123, 'exp' => Time.now.utc.to_i }
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
              }.to raise_error(VCAP::UaaTokenDecoder::BadToken)
            end
          end

          context 'and that grace period interval is negative' do
            subject { described_class.new(config_hash, -10) }

            it 'sets the grace period to be 0 instead' do
              token_content['exp'] = Time.now.utc.to_i
              expired_token = generate_token(rsa_key, token_content)
              allow(logger).to receive(:warn)
              expect {
                subject.decode_token("bearer #{expired_token}")
              }.to raise_error(VCAP::UaaTokenDecoder::BadToken)

              token_content['exp'] = Time.now.utc.to_i + 1
              valid_token = generate_token(rsa_key, token_content)
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
