require 'cloud_controller/encryptor'

module VCAP::CloudController
  shared_examples 'a model with an encrypted attribute' do
    before do
      allow(Encryptor).to receive(:db_encryption_key).and_return('correct-key')
    end

    def new_model
      model_class.make.tap do |model|
        model.update(encrypted_attr => value_to_encrypt)
      end
    end

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
      expect(saved_attribute).not_to include value_to_encrypt
    end

    it 'is decrypted when it is read from the database' do
      expect(model_class.last.refresh.send(encrypted_attr)).to eq(value_to_encrypt)
    end

    it 'uses the db_encryption_key from the config file' do
      saved_attribute = last_row[storage_column]

      expect(
        Encryptor.decrypt(saved_attribute, model.send(attr_salt))
      ).to include(value_to_encrypt)

      saved_attribute = last_row[storage_column]
      expect(saved_attribute).not_to be_nil

      allow(Encryptor).to receive(:db_encryption_key).and_return('a-totally-different-key')

      decrypted_value = nil
      errored = false

      begin
        decrypted_value = Encryptor.decrypt(saved_attribute, model.salt)
      rescue OpenSSL::Cipher::CipherError
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

    it 'must have a salt of length 8' do
      expect(model.reload.send(attr_salt).length).to eq 8
    end
  end
end
