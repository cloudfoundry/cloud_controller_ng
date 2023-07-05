module VCAP::CloudController
  class UaaHttpClient
    include CF::UAA::Http

    def initialize(target, auth_header, options={})
      @target = target
      @auth_header = auth_header
      initialize_http_options(options)
    end

    def get(path)
      json_get(@target, path, nil, headers)
    end

    private

    def headers
      @auth_header.empty? ? {} : { 'authorization' => @auth_header }
    end
  end

  class UaaClient
    attr_reader :subdomain, :zone, :client_id, :secret, :ca_file, :http_timeout

    def self.default_http_timeout
      @default_http_timeout ||= VCAP::CloudController::Config.config.get(:uaa, :client_timeout)
    end

    def auth_header
      return '' if client_id.empty?

      # TODO: [UAA ZONES] Cache token per client_id + subdomain.
      # token = UaaTokenCache.get_token(client_id)
      # return token if token
      #
      # UaaTokenCache.set_token(client_id, token_info.auth_header, expires_in: token_info.info['expires_in'])
      token_info.auth_header
    end

    def initialize(uaa_target:, subdomain: '', zone: '', client_id: '', secret: '', ca_file:)
      @uaa_target = uaa_target
      @subdomain = subdomain
      @zone = zone
      @client_id = client_id
      @secret = secret
      @ca_file = ca_file
      @http_timeout = self.class.default_http_timeout
    end

    def uaa_target
      return @uaa_target if subdomain.empty?

      uri = Addressable::URI.parse(@uaa_target)
      uri.host = "#{subdomain}.#{uri.host}"
      uri.to_s
    end

    def get_clients(client_ids)
      client_ids.map do |id|
        get(:client, id)
      rescue CF::UAA::NotFound
        nil
      end.compact
    end

    def token_info
      token_issuer.client_credentials_grant
    rescue CF::UAA::NotFound, CF::UAA::BadTarget, CF::UAA::BadResponse => e
      logger.error("UAA request for token failed: #{e.inspect}")
      raise UaaUnavailable
    end

    def users_for_ids(user_ids)
      fetch_users(user_ids)
    rescue UaaUnavailable, CF::UAA::UAAError => e
      logger.error("Failed to retrieve users from UAA: #{e.inspect}")
      {}
    end

    def usernames_for_ids(user_ids)
      fetch_users(user_ids).transform_values { |user| user['username'] }
    rescue UaaUnavailable, CF::UAA::UAAError => e
      logger.error("Failed to retrieve usernames from UAA: #{e.inspect}")
      {}
    end

    def id_for_username(username, origin: nil)
      filter_string = %(username eq "#{username}")
      filter_string = %/origin eq "#{origin}" and #{filter_string}/ if origin.present?
      # TODO: [UAA ZONES] Is the changed query semantically identical?
      results = query(:user, filter: filter_string, sort_by: 'username', attributes: 'id')

      user = results['resources'].first
      user && user['id']
    rescue CF::UAA::UAAError => e
      logger.error("Failed to retrieve user id from UAA: #{e.inspect}")
      raise UaaUnavailable
    end

    def ids_for_usernames_and_origins(usernames, origins, precise_username_match=true)
      operator = precise_username_match ? 'eq' : 'co'
      username_filter_string = usernames&.map { |u| "username #{operator} \"#{u}\"" }&.join(' or ')
      origin_filter_string = origins&.map { |o| "origin eq \"#{o}\"" }&.join(' or ')

      filter_string = construct_filter_string(username_filter_string, origin_filter_string)
      # TODO: [UAA ZONES] Is the changed query semantically identical?
      results = query(:user, filter: filter_string, sort_by: 'username', attributes: 'id')

      results['resources'].map { |r| r['id'] }
    rescue CF::UAA::UAAError => e
      logger.error("Failed to retrieve user ids from UAA: #{e.inspect}")
      raise UaaUnavailable
    end

    def construct_filter_string(username_filter_string, origin_filter_string)
      if username_filter_string && origin_filter_string
        "( #{username_filter_string} ) and ( #{origin_filter_string} )"
      else
        username_filter_string || origin_filter_string
      end
    end

    def origins_for_username(username)
      filter_string = %(username eq "#{username}")
      # TODO: [UAA ZONES] Is the changed query semantically identical?
      results = query(:user, filter: filter_string, sort_by: 'username', attributes: 'id,origin')

      results['resources'].map { |resource| resource['origin'] }
    rescue UaaUnavailable, CF::UAA::UAAError => e
      logger.error("Failed to retrieve origins from UAA: #{e.inspect}")
      raise UaaUnavailable
    end

    def info
      CF::UAA::Info.new(uaa_target, uaa_connection_opts)
    end

    def http_get(path)
      http_client.get(path)
    end

    private

    def query(type, **opts)
      with_cache_retry { scim.query(type, **opts) }
    end

    def get(type, id)
      with_cache_retry { scim.get(type, id) }
    end

    def with_cache_retry
      yield
    rescue CF::UAA::InvalidToken
      UaaTokenCache.clear_token(client_id)
      yield
    end

    def fetch_users(user_ids)
      return {} unless user_ids.present?

      results_hash = {}

      user_ids.each_slice(200) do |batch|
        filter_string = batch.map { |user_id| %(id eq "#{user_id}") }.join(' or ')
        filter_string = %/active eq true and ( #{filter_string} )/
        # TODO: [UAA ZONES] Is the changed query semantically identical?
        results = query(:user, filter: filter_string, count: batch.length, sort_by: 'username', attributes: 'id,username,origin')
        results['resources'].each do |user|
          results_hash[user['id']] = user
        end
      end

      results_hash
    end

    def scim
      opts = uaa_connection_opts
      opts.merge!({ zone: zone }) unless zone.empty?
      CF::UAA::Scim.new(uaa_target, auth_header, opts)
    end

    def token_issuer
      raise ArgumentError.new('TokenIssuer requires client_id') if client_id.empty?

      CF::UAA::TokenIssuer.new(uaa_target, client_id, secret, uaa_connection_opts)
    end

    def http_client
      UaaHttpClient.new(uaa_target, auth_header, uaa_connection_opts)
    end

    def uaa_connection_opts
      {
        skip_ssl_validation: false,
        ssl_ca_file: ca_file,
        http_timeout: http_timeout
      }
    end

    def logger
      @logger ||= Steno.logger('cc.uaa_client')
    end
  end

  class UaaZones
    def self.get_subdomain(uaa_client, zone_id)
      return '' if uaa_client.nil? || zone_id.nil?

      zone = uaa_client.http_get("/identity-zones/#{zone_id}")
      zone['subdomain']
    rescue CF::UAA::NotFound
      raise 'invalid zone id'
    end
  end
end
