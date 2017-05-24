module VCAP::CloudController
  class UaaClient
    attr_reader :uaa_target, :client_id, :secret, :ca_file

    def initialize(uaa_target:, client_id:, secret:, ca_file:)
      @uaa_target = uaa_target
      @client_id  = client_id
      @secret     = secret
      @ca_file    = ca_file
    end

    def scim
      @scim ||= CF::UAA::Scim.new(uaa_target, token_info.auth_header, uaa_connection_opts)
    end

    def get_clients(client_ids)
      client_ids.map do |id|
        begin
          scim.get(:client, id)
        rescue CF::UAA::NotFound
          nil
        end
      end.compact
    end

    def token_info
      token_issuer.client_credentials_grant
    rescue CF::UAA::NotFound, CF::UAA::BadTarget, CF::UAA::BadResponse => e
      logger.error("UAA request for token failed: #{e.inspect}")
      raise UaaUnavailable.new
    end

    def usernames_for_ids(user_ids)
      return {} unless user_ids.present?
      filter_string = user_ids.map { |user_id| %(id eq "#{user_id}") }.join(' or ')
      results       = scim.query(:user_id, filter: filter_string)

      results['resources'].each_with_object({}) do |resource, results_hash|
        results_hash[resource['id']] = resource['username']
        results_hash
      end
    rescue UaaUnavailable, CF::UAA::UAAError => e
      logger.error("Failed to retrieve usernames from UAA: #{e.inspect}")
      {}
    end

    def id_for_username(username)
      filter_string = %(username eq "#{username}")
      results       = scim.query(:user_id, filter: filter_string)

      user = results['resources'].first
      user && user['id']
    rescue CF::UAA::TargetError
      raise UaaEndpointDisabled
    end

    def info
      CF::UAA::Info.new(uaa_target, uaa_connection_opts)
    end

    private

    def token_issuer
      CF::UAA::TokenIssuer.new(uaa_target, client_id, secret, uaa_connection_opts)
    end

    def uaa_connection_opts
      {
        skip_ssl_validation: false,
        ssl_ca_file:         ca_file
      }
    end

    def logger
      @logger ||= Steno.logger('cc.uaa_client')
    end
  end
end
