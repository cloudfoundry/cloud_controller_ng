module CloudController
  class DomainDecorator
    DOMAIN_REGEX = /\A(([a-z0-9]|[a-z0-9][a-z0-9\-]{0,61}[a-z0-9])\.)+([a-z0-9]|[a-z0-9][a-z0-9\-]{0,61}[a-z0-9])\Z/ix.freeze
    DOMAIN_DELIMITER = '.'.freeze

    attr_reader :name

    def initialize(name)
      @name = name
    end

    def intermediate_domains
      return [] unless name && valid_format?

      name.split(DOMAIN_DELIMITER).reverse.inject([]) do |array, member|
        array.push(array.empty? ? member : "#{member}#{DOMAIN_DELIMITER}#{array.last}")
      end.drop(1).map { |intermediate_domain| DomainDecorator.new(intermediate_domain) }
    end

    def has_sub_domain?(test_domains:)
      return true if test_domains == [name]

      test_domains.any? do |test_domain|
        DomainDecorator.new(test_domain).is_sub_domain_of?(parent_domain_name: name)
      end
    end

    def to_s
      name
    end

    def is_sub_domain_of?(parent_domain_name:)
      parent_domain_name != name && intermediate_domains.map(&:name).include?(parent_domain_name)
    end

    def parent_domain
      DomainDecorator.new(split[:parent_domain])
    end

    def hostname
      split[:hostname]
    end

    def valid_format?
      name.match?(DOMAIN_REGEX)
    end

    def ==(other)
      name == other.name
    end

    private

    def split
      words = name.split(DOMAIN_DELIMITER, 2)
      if words.length == 2
        { hostname: words[0], parent_domain: words[1] }
      else
        { parent_domain: words.first }
      end
    end
  end
end
