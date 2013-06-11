require "cloudfront-signer"

module CCInitializers
  def self.cloudfront_signer(cc_config)
    return unless cc_config[:droplets][:cdn] && cc_config[:droplets][:cdn][:private_key]

    key_file = Tempfile.new("pk-cdn.pem")
    key_file.write(cc_config[:droplets][:cdn][:private_key])
    key_file.close

    AWS::CF::Signer.configure do |config|
      config.key_path = key_file.path
      config.key_pair_id = cc_config[:droplets][:cdn][:key_pair_id]
      config.default_expires = 600
    end
  end
end