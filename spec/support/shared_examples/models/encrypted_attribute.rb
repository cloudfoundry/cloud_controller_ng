require 'cloud_controller/encryptor'

module VCAP::CloudController
  RSpec.shared_examples 'a model with an encrypted attribute' do
    before do
      allow(Encryptor).to receive(:database_encryption_keys).
        and_return({ Encryptor.current_encryption_key_label.to_sym => 'correct-key' })
    end

    def new_model
      model_factory.call.tap do |model|
        model.update(encrypted_attr => value_to_encrypt)
      end
    end

    let(:model_factory) { -> { model_class.make } }
    let(:model_class) { described_class }
    let(:value_to_encrypt) { 'this-is-a-secret' }
    let!(:model) { new_model }
    let(:storage_column) { encrypted_attr }
    let(:attr_salt) { "#{encrypted_attr}_salt" }

    def last_row
      model_class.dataset.naked.order_by(:id).last
    end

    it 'is encrypted before being written to the database' do
      saved_attribute = last_row[storage_column]
      serialized_value = value_to_encrypt.is_a?(Hash) ? Oj.dump(value_to_encrypt) : value_to_encrypt

      expect(saved_attribute).not_to include serialized_value
    end

    it 'is decrypted when it is read from the database' do
      expect(model_class.last.refresh.send(encrypted_attr)).to eq(value_to_encrypt)
    end

    it 'uses the db_encryption_key from the config file' do
      saved_attribute = last_row[storage_column]

      serialized_value = value_to_encrypt.is_a?(Hash) ? Oj.dump(value_to_encrypt) : value_to_encrypt
      expect(
        Encryptor.decrypt(saved_attribute, model.send(attr_salt), label: model.encryption_key_label, iterations: model.encryption_iterations)
      ).to include(serialized_value)

      expect(saved_attribute).not_to be_nil

      allow(Encryptor).to receive(:database_encryption_keys).
        and_return({ Encryptor.current_encryption_key_label.to_sym => 'a-totally-different-key' })

      decrypted_value = nil
      errored = false

      begin
        decrypted_value = Encryptor.decrypt(saved_attribute, model.send(attr_salt), label: model.encryption_key_label, iterations: model.encryption_iterations)
      rescue VCAP::CloudController::Encryptor::EncryptorError
        errored = true
      end

      failed_to_recover_plaintext = errored || (decrypted_value != value_to_encrypt)

      expect(failed_to_recover_plaintext).to be true
    end

    it 'uses a salt, so that every row is encrypted with a different key' do
      value_with_original_salt = last_row[storage_column]
      new_model
      expect(value_with_original_salt).not_to eql(last_row[storage_column])
    end

    it 'must have a salt of length 16' do
      expect(model.reload.send(attr_salt).length).to eq 16
    end
  end
end
