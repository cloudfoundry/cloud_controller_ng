module VCAP::Services::ServiceBrokers::V2
  class CatalogSchemas
    attr_reader :errors, :create_instance

    def initialize(attrs)
      @errors = VCAP::Services::ValidationErrors.new
      validate_and_populate_create_instance(attrs)
    end

    def valid?
      errors.empty?
    end

    private

    def validate_and_populate_create_instance(attrs)
      return unless attrs
      unless attrs.is_a? Hash
        errors.add("Schemas must be a hash, but has value #{attrs.inspect}")
        return
      end

      path = []
      ['service_instance', 'create', 'parameters'].each do |key|
        path += [key]
        attrs = attrs[key]
        return nil unless attrs

        unless attrs.is_a? Hash
          errors.add("Schemas #{path.join('.')} must be a hash, but has value #{attrs.inspect}")
          return nil
        end
      end

      @create_instance = attrs
    end
  end
end
