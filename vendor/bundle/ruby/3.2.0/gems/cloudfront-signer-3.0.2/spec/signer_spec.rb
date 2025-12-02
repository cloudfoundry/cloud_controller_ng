require 'spec_helper'

RSpec.shared_examples 'is configured' do
  it 'is configured' do
    expect(Aws::CF::Signer.is_configured?).to be true
  end

  it 'sets the private_key' do
    expect(Aws::CF::Signer.send(:private_key)).to(
      be_an_instance_of(OpenSSL::PKey::RSA)
    )
  end
end

FILES_PATH = File.expand_path(File.dirname(__FILE__) + '/files')
KEY_PAIR_ID = 'APKAIKUROOUNR2BAFUUU'.freeze

RSpec.describe Aws::CF::Signer do
  let(:key_path) { FILES_PATH + "/pk-#{KEY_PAIR_ID}.pem" }
  let(:other_key_path) { FILES_PATH + '/private_key.pem' }
  let(:key) { File.readlines(key_path).join '' }

  describe 'Errors' do
    it 'raises ArgumentError when invalid path is passed to key_path' do
      expect do
        Aws::CF::Signer.configure { |config| config.key_path = 'foo/bar' }
      end.to raise_error ArgumentError
    end

    it 'raises OpenSSL::PKey::RSAError when invalid key is passed' do
      expect do
        Aws::CF::Signer.configure { |config| config.key = '' }
      end.to raise_error OpenSSL::PKey::RSAError
    end

    it 'raises ArgumentError when no key is provided through private_key' do
      expect do
        Aws::CF::Signer.configure { |_config| }
      end.to raise_error ArgumentError
    end

    it "raises ArgumentError when no key is provided through key_path doesn't" \
         'allow to guess key_pair_id' do
      expect do
        Aws::CF::Signer.configure { |config| config.key_path = other_key_path }
      end.to raise_error ArgumentError
    end
  end

  describe 'Defaults' do
    it 'expire urls and paths in one hour by default' do
      expect(Aws::CF::Signer.default_expires).to eq 3600
    end

    it 'expires when specified' do
      Aws::CF::Signer.default_expires = 600
      expect(Aws::CF::Signer.default_expires).to eq 600
      Aws::CF::Signer.default_expires = nil
    end
  end

  context 'When configured with key and key_pair_id' do
    before do
      Aws::CF::Signer.configure do |config|
        config.key_pair_id = KEY_PAIR_ID
        config.key = key
      end
    end

    include_examples 'is configured'
  end

  context 'When configured with key_path' do
    before(:each) do
      Aws::CF::Signer.configure { |config| config.key_path = key_path }
    end

    describe 'before default use' do
      include_examples 'is configured'
    end

    describe 'when signing a url' do
      let(:url) { 'https://example.com/somerésource?opt1=one&opt2=two' }
      let(:url_with_spaces) { 'http://example.com/sign me' }

      it "doesn't modifies the passed url" do
        url = 'http://example.com/'.freeze
        expect(Aws::CF::Signer.sign_url(url)).not_to match(/\s/)
      end

      it 'removes spaces' do
        expect(Aws::CF::Signer.sign_url(url_with_spaces)).not_to match(/\s/)
      end

      it "doesn't HTML encode the signed url by default" do
        expect(Aws::CF::Signer.sign_url(url)).to match(/\?|=|&/)
      end

      it 'HTML encodes the signed url when using sign_url_safe' do
        expect(Aws::CF::Signer.sign_url_safe(url)).not_to match(/\?|=|&/)
      end

      it 'URL encodes the signed URL when using sign_url_escaped' do
        expect(Aws::CF::Signer.sign_url_escaped(url)).not_to match(/é/)
      end
    end

    describe 'when signing a path' do
      it "doesn't remove spaces" do
        path = '/prefix/sign me'
        expect(Aws::CF::Signer.sign_path(path)).to match(/\s/)
      end

      it 'HTML encodes the signed path when using sign_path_safe' do
        path = '/prefix/sign me?'
        expect(Aws::CF::Signer.sign_path_safe(path)).not_to match(/\?|=|&/)
      end

      it 'URL encodes the signed path when using sign_path_escaped' do
        path = '/préfix/sign me?'
        expect(Aws::CF::Signer.sign_path_escaped(path)).not_to match(/[é ]+/)
      end
    end

    describe ':expires option' do
      subject(:sign_url) { Aws::CF::Signer.sign_url '', expires: expires }

      { 'Time' => Time.now,
        'String' => '2018-01-01',
        'Integer' => 1_514_782_800,
        'NilClass' => nil }.each do |klass, value|
        context "as a #{klass}" do
          let(:expires) { value }
          it "doesn't raise an error" do
            expect { subject }.not_to raise_error
          end
        end
      end

      context 'not as a String, Integer or Time' do
        let(:expires) { [[], {}, true, 1.0].sample }
        it 'raises ArgumentError' do
          expect { subject }.to raise_error ArgumentError
        end
      end
    end

    describe 'Custom Policy' do
      it 'builds policy from policy_options' do
        signed_url = Aws::CF::Signer.sign_url(
          'https://d84l721fxaaqy9.cloudfront.net/downloads/pictures.tgz',
          starting: 'Thu, 30 Apr 2009 06:43:10 GMT',
          expires: 'Fri, 16 Oct 2009 06:31:56 GMT',
          resource: 'https://d84l721fxaaqy9.cloudfront.net/downloads/',
          ip_range: '216.98.35.1/32'
        )
        policy_value = get_query_value(signed_url, 'Policy')
        expect(policy_value).not_to be_empty
      end

      it 'builds policy from policy_file' do
        signed_url = Aws::CF::Signer.sign_url(
          'https://d84l721fxaaqy9.cloudfront.net/downloads/pictures.tgz',
          policy_file: FILES_PATH + '/custom_policy.json'
        )
        policy_value = get_query_value(signed_url, 'Policy')
        expect(policy_value).not_to be_empty
      end
    end
  end
end
