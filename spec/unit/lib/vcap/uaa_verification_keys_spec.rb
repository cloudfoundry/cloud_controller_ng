require 'spec_helper'
require 'vcap/uaa_verification_keys'

module VCAP
  RSpec.describe UaaVerificationKeys do
    subject { described_class.new(uaa_info) }

    let(:config_hash) { { url: 'http://uaa-url' } }
    let(:uaa_info) { double(CF::UAA::Info) }
    let(:key_hash) { { 'key-name' => { 'value' => 'value-from-uaa' } } }

    describe '#value' do
      context 'when verification key is nil' do
        before { config_hash[:verification_key] = nil }
        before { allow(uaa_info).to receive_messages(validation_keys_hash: key_hash) }

        context 'when key was never fetched' do
          it 'is fetched' do
            expect(uaa_info).to receive(:validation_keys_hash)
            expect(subject.value).to eq ['value-from-uaa']
          end
        end
      end

      context 'when verification key is an empty string' do
        before { config_hash[:verification_key] = '' }
        before { allow(uaa_info).to receive_messages(validation_keys_hash: key_hash) }

        context 'when key was never fetched' do
          it 'is fetched' do
            expect(uaa_info).to receive(:validation_keys_hash)
            expect(subject.value).to eq ['value-from-uaa']
          end
        end
      end

      context 'when key was fetched more than 30 seconds ago' do
        before { allow(uaa_info).to receive_messages(validation_keys_hash: key_hash) }
        let(:key_hash2) { { 'key-name' => { 'value' => 'another-from-uaa' } } }

        it 're-fetches the key' do
          Timecop.freeze do
            subject.value
            Timecop.travel(40)
            allow(uaa_info).to receive_messages(validation_keys_hash: key_hash2)
            subject.value
          end

          expect(subject.value).to eq(['another-from-uaa'])
        end
      end

      context 'when key was fetched less than 30 seconds ago' do
        before { allow(uaa_info).to receive_messages(validation_keys_hash: key_hash) }
        let(:key_hash2) { { 'key-name' => { 'value' => 'another-from-uaa' } } }

        it 'does not fetch the keys' do
          Timecop.freeze do
            subject.value
            Timecop.travel(25)
            allow(uaa_info).to receive_messages(validation_keys_hash: key_hash2)
            subject.value
          end
          expect(subject.value).to eq(['value-from-uaa'])
        end
      end
    end

    describe '#refresh' do
      context 'when config does not specify verification key' do
        before { config_hash[:verification_key] = nil }
        before { allow(uaa_info).to receive_messages(validation_keys_hash: key_hash) }

        context 'when key was never fetched' do
          it 'is fetched' do
            expect(uaa_info).to receive(:validation_keys_hash)
            subject.refresh
            expect(subject.value).to eq(['value-from-uaa'])
          end
        end

        context 'when key was fetched before' do
          before do
            expect(uaa_info).to receive(:validation_keys_hash)
            subject.value
          end

          it 'is RE-fetched again' do
            expect(uaa_info).to receive(:validation_keys_hash)
            subject.refresh
            expect(subject.value).to eq(['value-from-uaa'])
          end
        end
      end
    end
  end
end
