module VCAP::CloudController
  class UaaClient
    attr_reader :uaa_target, :client_id, :secret, :ca_file, :http_timeout

    def self.default_http_timeout
      @default_http_timeout ||= VCAP::CloudController::Config.config.get(:uaa, :client_timeout)
    end

    def auth_header
      token = UaaTokenCache.get_token(client_id)
      return token if token

      UaaTokenCache.set_token(client_id, token_info.auth_header, expires_in: token_info.info['expires_in'])
      token_info.auth_header
    end

    def initialize(uaa_target:, client_id:, secret:, ca_file:)
      @uaa_target = uaa_target
      @client_id = client_id
      @secret = secret
      @ca_file = ca_file
      @http_timeout = self.class.default_http_timeout
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
      with_request_error_handling { fetch_users(user_ids) }
    end

    def usernames_for_ids(user_ids)
      fetch_users(user_ids).transform_values { |user| user['username'] }
    rescue UaaUnavailable, CF::UAA::UAAError => e
      logger.error("Failed to retrieve usernames from UAA: #{e.inspect}#{error_info_from_target_error(e)}")
      {}
    end

    def id_for_username(username, origin: nil)
      filter_string = %(username eq #{Oj.dump(username)})
      filter_string = %(origin eq #{Oj.dump(origin)} and #{filter_string}) if origin.present?
      results = query(:user_id, includeInactive: true, filter: filter_string)

      user = results['resources'].first
      user && user['id']
    rescue CF::UAA::UAAError => e
      logger.error("Failed to retrieve user id from UAA: #{e.inspect}#{error_info_from_target_error(e)}")
      raise UaaUnavailable
    end

    def ids_for_usernames_and_origins(usernames, origins, precise_username_match=true)
      with_request_error_handling do
        operator = precise_username_match ? 'eq' : 'co'
        username_filter_string = usernames&.map { |u| "username #{operator} #{Oj.dump(u)}" }&.join(' or ')
        origin_filter_string = origins&.map { |o| "origin eq #{Oj.dump(o)}" }&.join(' or ')

        filter_string = construct_filter_string(username_filter_string, origin_filter_string)

        results = if precise_username_match
                    query(:user_id, includeInactive: true, filter: filter_string)
                  else
                    query(:user, filter: filter_string, attributes: 'id')
                  end

        results['resources'].pluck('id')
      end
    end

    def construct_filter_string(username_filter_string, origin_filter_string)
      if username_filter_string && origin_filter_string
        "( #{username_filter_string} ) and ( #{origin_filter_string} )"
      else
        username_filter_string || origin_filter_string
      end
    end

    def origins_for_username(username)
      filter_string = %(username eq #{Oj.dump(username)})
      results = query(:user_id, includeInactive: true, filter: filter_string)

      results['resources'].pluck('origin')
    rescue UaaUnavailable, CF::UAA::UAAError => e
      logger.error("Failed to retrieve origins from UAA: #{e.inspect}#{error_info_from_target_error(e)}")
      raise UaaUnavailable
    end

    def create_shadow_user(username, origin)
      with_cache_retry { scim.add(:user, { username: username, origin: origin, emails: [{ primary: true, value: username }] }) }
    rescue CF::UAA::TargetError => e
      raise e unless e.info['error'] == 'scim_resource_already_exists'

      { 'id' => e.info['user_id'] }
    rescue CF::UAA::UAAError => e
      logger.error("UAA request for creating a user failed: #{e.inspect}")
      raise UaaUnavailable
    end

    def info
      CF::UAA::Info.new(uaa_target, uaa_connection_opts)
    end

    def with_request_error_handling
      delay = 0.25
      max_delay = 5
      retry_until = Time.now.utc + 60 # retry for 1 minute from now
      factor = 2

      begin
        yield
      rescue CF::UAA::InvalidToken => e
        logger.error("UAA request for token failed: #{e.inspect}")
        raise
      rescue UaaUnavailable, CF::UAA::UAAError => e
        if Time.now.utc > retry_until
          logger.error('Unable to establish a connection to UAA, no more retries, raising an exception.')
          raise UaaUnavailable
        else
          sleep_time = [delay, max_delay].min
          logger.error("Failed to retrieve details from UAA: #{e.inspect}#{error_info_from_target_error(e)}")
          logger.info("Attempting to connect to the UAA. Total #{(retry_until - Time.now.utc).round(2)} seconds remaining. Next retry after #{sleep_time} seconds.")
          sleep(sleep_time)
          delay *= factor
          retry
        end
      end
    end

    private

    def query(type, **)
      with_cache_retry { scim.query(type, **) }
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

    def scim
      CF::UAA::Scim.new(uaa_target, auth_header, uaa_connection_opts)
    end

    def fetch_users(user_ids)
      return {} if user_ids.blank?

      results_hash = {}

      user_ids.each_slice(200) do |batch|
        filter_string = batch.map { |user_id| %(id eq #{Oj.dump(user_id.to_s)}) }.join(' or ')
        results = query(:user_id, filter: filter_string, count: batch.length)
        results['resources'].each do |user|
          results_hash[user['id']] = user
        end
      end

      results_hash
    end

    def token_issuer
      CF::UAA::TokenIssuer.new(uaa_target, client_id, secret, uaa_connection_opts)
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

    def error_info_from_target_error(e)
      e.is_a?(CF::UAA::TargetError) ? ", error_info: #{e.info}" : ''
    end
  end
end
