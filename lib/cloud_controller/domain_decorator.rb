module CloudController
  class DomainDecorator
    DOMAIN_REGEX = /\A(([a-z0-9]|[a-z0-9][a-z0-9\-]{0,61}[a-z0-9])\.)+([a-z0-9]|[a-z0-9][a-z0-9\-]{0,61}[a-z0-9])\Z/ix

    attr_reader :name

    def initialize(name)
      @name = name
    end

    def intermediate_domains
      return [] unless name && valid_format?

      name.split('.').reverse.inject([]) do |array, member|
        array.push(array.empty? ? member : "#{member}.#{array.last}")
      end.drop(1)
    end

    def is_sub_domain?(test_domains:)
      return true if test_domains.length == 1 && name == test_domains.first
      test_domains.any? do |test_domain|
        if test_domain != name
          DomainDecorator.new(test_domain).intermediate_domains.include?(name)
        end
      end
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
      words = name.split('.', 2)
      if words.length == 2
        { hostname: words[0], parent_domain: words[1] }
      else
        { parent_domain: words.first }
      end
    end
  end
end
