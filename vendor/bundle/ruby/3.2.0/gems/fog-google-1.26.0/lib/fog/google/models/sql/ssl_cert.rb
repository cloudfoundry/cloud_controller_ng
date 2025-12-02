require "fog/core/model"

module Fog
  module Google
    class SQL
      ##
      # A SSL certificate resource
      #
      # @see https://cloud.google.com/sql/docs/mysql/admin-api/v1beta4/sslCerts
      class SslCert < Fog::Model
        identity :sha1_fingerprint, :aliases => "sha1Fingerprint"

        attribute :cert
        attribute :cert_serial_number, :aliases => "certSerialNumber"
        attribute :common_name, :aliases => "commonName"
        attribute :create_time, :aliases => "createTime"
        attribute :expiration_time, :aliases => "expirationTime"
        attribute :instance
        attribute :kind
        attribute :self_link, :aliases => "selfLink"

        # These attributes are not available in the representation of a 'SSL Certificate' returned by the SQL API.
        # These attributes are only available as a response to a create operation
        attribute :server_ca_cert, :aliases => "serverCaCert"
        attribute :cert_private_key, :aliases => "certPrivateKey"

        ##
        # Deletes a SSL certificate. The change will not take effect until the instance is restarted.
        #
        # @param async [Boolean] If the operation must be performed asynchronously (true by default)
        # @return [Fog::Google::SQL::Operation] A Operation resource
        def destroy(async: true)
          requires :instance, :identity

          data = service.delete_ssl_cert(instance, identity)
          operation = Fog::Google::SQL::Operations.new(:service => service).get(data.name)
          operation.wait_for { ready? } unless async
          operation
        end

        ##
        # Reloads a SSL certificate
        #
        # @return [Fog::Google::SQL::SslCert] SSL certificate resource
        def reload
          requires :instance, :identity

          data = collection.get(instance, identity)
          merge_attributes(data.attributes)
          self
        end

        ##
        # Creates a SSL certificate. The new certificate will not be usable until the instance is restarted.
        #
        # @raise [Fog::Errors::Error] If SSL certificate already exists
        def save(async: false)
          requires :instance, :common_name

          raise Fog::Errors::Error.new("Resaving an existing object may create a duplicate") if persisted?

          data = service.insert_ssl_cert(instance, common_name)
          # data.operation.name is used here since InsertSslCert returns a
          # special object, not an operation, as usual. See documentation:
          # https://cloud.google.com/sql/docs/mysql/admin-api/rest/v1beta4/sslCerts/insert#response-body
          operation = Fog::Google::SQL::Operations.new(:service => service).get(data.operation.name)
          operation.wait_for { ready? } unless async

          merge_attributes(data.client_cert.cert_info.to_h)
          self.server_ca_cert = Fog::Google::SQL::SslCert.new(data.server_ca_cert.to_h)
          self.cert_private_key = data.client_cert.cert_private_key
          self
        end
      end
    end
  end
end
