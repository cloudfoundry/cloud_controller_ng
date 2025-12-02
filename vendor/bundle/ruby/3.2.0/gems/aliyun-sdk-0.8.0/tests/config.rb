class TestConf
  class << self
    def creds
      {
        access_key_id: ENV['RUBY_SDK_OSS_ID'],
        access_key_secret: ENV['RUBY_SDK_OSS_KEY'],
        download_crc_enable: ENV['RUBY_SDK_OSS_DOWNLOAD_CRC_ENABLE'],
        upload_crc_enable: ENV['RUBY_SDK_OSS_UPLOAD_CRC_ENABLE'],
        endpoint: ENV['RUBY_SDK_OSS_ENDPOINT']
      }
    end

    def bucket
      ENV['RUBY_SDK_OSS_BUCKET']
    end

    def sts_creds
      {
        access_key_id: ENV['RUBY_SDK_STS_ID'],
        access_key_secret: ENV['RUBY_SDK_STS_KEY'],
        endpoint: ENV['RUBY_SDK_STS_ENDPOINT']
      }
    end

    def sts_role
      ENV['RUBY_SDK_STS_ROLE']
    end

    def sts_bucket
      ENV['RUBY_SDK_STS_BUCKET']
    end
  end
end
