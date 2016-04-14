require 'cloud_controller/domain_helper'

module CloudController
  describe DomainHelper do
    describe '.intermediate_domains' do
      # TODO: (pego): not sure this is really what we want or if we want this to raise an error
      it 'returns an empty array if the name is nil' do
        expect(DomainHelper.intermediate_domains(nil)).to be_empty
      end

      # TODO: (pego): not sure this is really what we want or if we want this to raise an error
      it 'returns an empty array if the name not a valid domain' do
        expect(DomainHelper.intermediate_domains('invalid_domain')).to be_empty
      end

      it 'returns all of the intermediate domains except the tld' do
        expect(DomainHelper.intermediate_domains('long.named.example.com')).
          to match_array(['long.named.example.com', 'named.example.com', 'example.com'])
      end
    end
  end
end


