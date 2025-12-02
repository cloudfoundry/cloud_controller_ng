module Fog
  module Google
    class Compute
      class TargetHttpsProxy < Fog::Model
        identity :name

        attribute :creation_timestamp, :aliases => "creationTimestamp"
        attribute :description, :aliases => "description"
        attribute :id, :aliases => "id"
        attribute :kind, :aliases => "kind"
        attribute :self_link, :aliases => "selfLink"
        attribute :url_map, :aliases => "urlMap"
        # Array of SSL Certificates
        # @example
        #
        #   [cert_one.self_link', cert_two.self_link]
        #
        # , where 'cert_one' and 'cert_two' are instances of
        # Fog::Google::Compute::SslCertificate
        #
        # @return [Array<String>]
        attribute :ssl_certificates, :aliases => "sslCertificates"

        def save
          requires :identity, :url_map, :ssl_certificates

          unless ssl_certificates.is_a?(Array)
            raise Fog::Errors::Error.new("ssl_certificates attribute must be an array")
          end

          data = service.insert_target_https_proxy(
            identity,
            :description => description,
            :url_map => url_map,
            :ssl_certificates => ssl_certificates
          )
          operation = Fog::Google::Compute::Operations.new(:service => service)
                                                      .get(data.name)
          operation.wait_for { ready? }
          reload
        end

        def destroy(async = true)
          requires :identity

          data = service.delete_target_https_proxy(identity)
          operation = Fog::Google::Compute::Operations.new(:service => service)
                                                      .get(data.name)
          operation.wait_for { ready? } unless async
          operation
        end

        def set_url_map(url_map, async = true)
          requires :identity

          data = service.set_target_https_proxy_url_map(
            identity, url_map
          )
          operation = Fog::Google::Compute::Operations.new(:service => service)
                                                      .get(data.name)
          operation.wait_for { ready? } unless async
          reload
        end

        def set_ssl_certificates(ssl_certificates, async = true)
          requires :identity

          data = service.set_target_https_proxy_ssl_certificates(
            identity, ssl_certificates
          )
          operation = Fog::Google::Compute::Operations.new(:service => service)
                                                      .get(data.name)
          operation.wait_for { ready? } unless async
          reload
        end

        def ready?
          requires :identity

          service.get_target_https_proxy(identity)
          true
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code == 404
          false
        end

        def reload
          requires :identity

          return unless data = begin
            collection.get(identity)
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
