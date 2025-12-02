module Fog
  module Google
    class Compute
      class UrlMap < Fog::Model
        identity :name

        attribute :creation_timestamp, :aliases => "creationTimestamp"
        attribute :default_service, :aliases => "defaultService"
        attribute :description, :aliases => "description"
        attribute :fingerprint, :aliases => "fingerprint"
        attribute :host_rules, :aliases => "hostRules"
        attribute :id, :aliases => "id"
        attribute :kind, :aliases => "kind"
        attribute :path_matchers, :aliases => "pathMatchers"
        attribute :self_link, :aliases => "selfLink"
        attribute :tests, :aliases => "tests"

        def save
          requires :identity, :default_service

          options = {
            :default_service => default_service,
            :description => description,
            :fingerprint => fingerprint,
            :host_rules => host_rules,
            :path_matchers => path_matchers,
            :tests => tests
          }

          # Update if creation_timestamp is set, create url map otherwise.
          data = nil
          if creation_timestamp
            data = service.update_url_map(identity, options)
          else
            data = service.insert_url_map(identity, options)
          end
          operation = Fog::Google::Compute::Operations.new(:service => service)
                                                      .get(data.name)
          operation.wait_for { ready? }
          reload
        end

        def destroy(async = true)
          requires :identity

          data = service.delete_url_map(identity)
          operation = Fog::Google::Compute::Operations.new(:service => service)
                                                      .get(data.name)
          operation.wait_for { ready? } unless async
          operation
        end

        def validate
          requires :identity
          service.validate_url_map(identity, attributes)
        end

        def add_host_rules(rules_to_add, async = true)
          requires :identity

          rules = (host_rules || []).concat rules_to_add
          data = service.patch_url_map(identity, :host_rules => rules)

          operation = Fog::Google::Compute::Operations.new(:service => service)
                                                      .get(data.name)
          operation.wait_for { ready? } unless async
          reload
        end

        def add_path_matchers(matchers_to_add, rules_to_add, async = true)
          requires :identity

          matchers = (path_matchers || []) + matchers_to_add
          rules = (host_rules || []) + rules_to_add
          data = service.patch_url_map(identity,
                                       :host_rules => rules,
                                       :path_matchers => matchers)

          operation = Fog::Google::Compute::Operations.new(:service => service)
                                                      .get(data.name)
          operation.wait_for { ready? } unless async
          reload
        end

        def invalidate_cache(path, host = nil, async = true)
          requires :identity

          data = service.invalidate_url_map_cache(identity, path, host)
          operation = Fog::Google::Compute::Operations.new(:service => service)
                                                      .get(data.name)
          operation.wait_for { ready? } unless async
          operation
        end

        def ready?
          service.get_url_map(name)
          true
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code == 404
          false
        end

        def reload
          requires :name

          return unless data = begin
            collection.get(name)
          rescue Excon::Errors::SocketError
            nil
          end

          new_attributes = data.attributes
          merge_attributes(new_attributes)
          self
        end

        RUNNING_STATE = "READY".freeze
      end
    end
  end
end
