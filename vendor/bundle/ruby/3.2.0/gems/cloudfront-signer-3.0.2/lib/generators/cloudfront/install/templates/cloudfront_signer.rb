Aws::CF::Signer.configure do |config|
  config.key_path = '/path/to/keyfile.pem'
  # or config.key = ENV.fetch('PRIVATE_KEY')
  config.key_pair_id = 'XXYYZZ'
  config.default_expires = 3600
end
