module CloudController
  class UrlSecretObfuscator
    def self.obfuscate(url)
      return nil if url.nil?
      parsed_url = Addressable::URI.parse(url)

      if parsed_url.user
        parsed_url.user = '***'
        parsed_url.password = '***'
      end

      parsed_url.to_s
    end
  end
end
