module Fog
  module OpenStack
    module Auth
      module Catalog
        attr_reader :payload

        class CatalogError < RuntimeError; end
        class EndpointError < RuntimeError; end
        class ServiceTypeError < RuntimeError; end

        def initialize(payload)
          @payload = payload
        end

        def get_endpoint_url(names, interfaces, region = nil)
          # TODO: Inject OpenStack Service Types Authority
          names_list = if names.kind_of?(String)
                         [names]
                       else
                         names
                       end
          entries = get_by_type(names_list)
          raise ServiceTypeError, 'No endpoint match' if entries.empty?

          interfaces_list = if interfaces.kind_of?(String)
                              [interfaces]
                            else
                              interfaces
                            end

          list = []
          interfaces_list.each do |interface|
            val = get_endpoint(entries, interface, region)
            list << val if val
          end

          raise EndpointError, 'No endpoint found' if list.empty?
          list[0]
        end

        private

        def get_by_type(names)
          raise CatalogError, 'Empty content' unless @payload
          @payload.select do |e|
            names.include?(e['type'])
          end
        end

        def get_endpoint(entries, interface, region)
          list = []
          entries.each do |type|
            next unless type.key?('endpoints')
            type['endpoints'].each do |endpoint|
              list << endpoint_url(endpoint, interface) if endpoint_match?(endpoint, interface, region)
            end
          end
          raise EndpointError, 'Multiple endpoints found' if list.size > 1
          list[0]
        end
      end
    end
  end
end
