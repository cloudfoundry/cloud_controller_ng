# deviates from other bin stuff to accomodate gem
module Google
  class << self
    def class_for(key)
      case key
      when :compute
        Fog::Google::Compute
      when :dns
        Fog::Google::DNS
      when :monitoring
        Fog::Google::Monitoring
      when :storage
        Fog::Google::Storage
      when :storage_json
        Fog::Google::Storage
      when :sql
        Fog::Google::SQL
      when :pubsub
        Fog::Google::Pubsub
      else
        raise ArgumentError, "Unsupported #{self} service: #{key}"
      end
    end

    def [](service)
      @@connections ||= Hash.new do |hash, key|
        case key
        when :compute
          hash[key] = Fog::Compute.new(:provider => "Google")
        when :dns
          hash[key] = Fog::DNS.new(:provider => "Google")
        when :monitoring
          hash[key] = Fog::Google::Monitoring.new
        when :sql
          hash[key] = Fog::Google::SQL.new
        when :pubsub
          hash[key] = Fog::Google::Pubsub.new
        when :storage
          hash[key] = Fog::Storage.new(:provider => "Google")
        else
          hash[key] = raise ArgumentError, "Unrecognized service: #{key.inspect}"
        end
      end
      @@connections[service]
    end

    def account
      @@connections[:compute].account
    end

    def services
      Fog::Google.services
    end

    # based off of virtual_box.rb
    def available?
      # Make sure the gem we use is enabled.
      if Gem::Specification.respond_to?(:find_all_by_name)
        # newest rubygems
        availability = !Gem::Specification.find_all_by_name("google-api-client").empty?
      else
        # legacy
        availability = !Gem.source_index.find_name("google-api-client").empty?
      end

      # Then make sure we have all of the requirements
      services.each do |service|
        begin
          service = class_for(service)
          availability &&= service.requirements.all? { |requirement| Fog.credentials.include?(requirement) }
        rescue ArgumentError => e
          Fog::Logger.warning(e.message)
          availability = false
        rescue StandardError => e
          availability = false
        end
      end

      if availability
        services.each do |service|
          class_for(service).collections.each do |collection|
            next if respond_to?(collection)

            class_eval <<-EOS, __FILE__, __LINE__ + 1
                def self.#{collection}
                  self[:#{service}].#{collection}
                end
            EOS
          end
        end
      end
      availability
    end
  end
end
