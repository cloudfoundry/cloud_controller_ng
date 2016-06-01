module CloudController
  module DomainHelper
    DOMAIN_REGEX = /^(([a-z0-9]|[a-z0-9][a-z0-9\-]{0,61}[a-z0-9])\.)+([a-z0-9]|[a-z0-9][a-z0-9\-]{0,61}[a-z0-9])$/ix

    def self.intermediate_domains(name)
      return [] unless name && name =~ DOMAIN_REGEX

      name.split('.').reverse.inject([]) do |array, member|
        array.push(array.empty? ? member : "#{member}.#{array.last}")
      end.drop(1)
    end

    def self.is_sub_domain?(domain:, test_domains:)
      return false if test_domains.length == 1 && domain == test_domains.first
      test_domains.any? do |test_domain|
        if test_domain != domain
          intermediate_domains(test_domain).include?(domain)
        end
      end
    end
  end
end
