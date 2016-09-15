module CloudController
  class UrlSecretObfuscator
    def self.obfuscate(url)
      return nil if url.nil?

      begin
        parsed_url = URI.parse(url)
      rescue URI::InvalidURIError
        return url
      end

      if parsed_url.user
        parsed_url.user = '***'
        parsed_url.password = '***'
      end

      parsed_url.to_s
    end
  end
end
