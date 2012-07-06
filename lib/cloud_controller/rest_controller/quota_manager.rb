# Copyright (c) 2009-2012 VMware, Inc.

require "httpclient"

module VCAP::CloudController::RestController
  module QuotaManager
    class << self
      # Set the configuration for the QuotaManager
      #
      # The most important attribute is the :policy attribute.
      # This can be either "MoneyMaker" or "BlindApproval"
      #
      # If MoneyMaker, the QuotaManager will attempt to get
      # quota approval from the account manger portion of the
      # MoneyMaker/Billing System.
      def configure(config)
        c = config[:quota_manager]
        policy_name = c[:policy] || "MoneyMaker"
        @policy = QuotaManager.const_get(policy_name)
        MoneyMakerClient.configure(c)
      end

      # Fetch a quota token. If the policy decision is denied,
      # an exception is raised.
      #
      # @param [Hash] quota_request.  There should be a :path entry
      # that is appened to the base url for the approval request.  The :body
      # entry is encoded as json and passed directly to the quota server.
      #
      # @return [QuotaManager::ApprovalToken] The caller should call commit
      # or abandon on the returned token.
      def fetch_quota_token(quota_request)
        p = quota_request ? @policy : BlindApproval
        logger.debug "@policy: #{p}"
        token = p.fetch_quota_token(quota_request)
        unless token.approved?
          raise VCAP::CloudController::Errors::QuotaDeclined.new(token.reason)
        end
        logger.debug "token: #{token.inspect}"
        token
      end

      def logger
        @logger ||= VCAP::Logging.logger("cc.qm")
      end
    end

    # BlindApprovalTokens are basically no-op tokens.
    class BlindApprovalToken

      # Perform a rollback with the quota system.
      #
      # @param [String] Error string indicating why the operation failed.
      def abandon(reason)
        logger.debug "blind abandon: #{reason}"
      end

      # Commit
      #
      # @param [String] Error string indicating why the operation failed.
      def commit
        logger.debug "blind commit"
      end

      # Approval check
      #
      # @return [Bool] True if the quota manager approved the quota check
      def approved?
        true
      end

      # Reason the quota manager denied the quota check
      #
      # @return [String] Reason the quota manager denied the quota check
      def reason
      end

      private

      def logger
        QuotaManager.logger
      end
    end

    # Blind Approval policy
    class BlindApproval
      def self.fetch_quota_token(quota_request)
        BlindApprovalToken.new
      end
    end

    # Approval token from the MoneyMaker quota manager.  Commit/abandon
    # result in a follow up call to the quota manager to complete
    # the processing of the token.
    class MoneyMakerApprovalToken
      def initialize(token_id, approved, reason = nil)
        @token_id = token_id
        @approved = approved
        @reason = reason
      end

      def approved?
        @approved
      end

      def reason
        @reason
      end

      def abandon(reason)
        MoneyMakerClient.abandon_token(@token_id, reason)
      end

      def commit
        MoneyMakerClient.commit_token(@token_id)
      end
    end

    # Money Maker approval policy
    class MoneyMakerApproval
      def self.fetch_quota_token(quota_request)
        resp = MoneyMakerClient.request_token(quota_request)
        MoneyMakerApprovalToken.new(resp["token"],
                                    resp["approved"] == "yes",
                                    resp["reason"])
      rescue MoneyMakerClient::MoneyMakerError => e
        logger.warn "BLIND APPROVAL: #{e}"
        BlindApprovalToken.new
      end

      def self.logger
        QuotaManager.logger
      end
    end


    # Money Maker rest client
    class MoneyMakerClient
      class MoneyMakerError < StandardError; end

      DEFAULT_HTTP_TIMEOUT_SEC = 2

      class << self
        def configure(config)
          @base_url = config[:base_url]
          @auth_token = config[:auth_token]
          @http_timeout = config[:http_timeout_sec]
        end

        def request_token(quota_request)
          begin
            url = quota_manager_url(quota_request[:path])
            response = post(url, quota_request[:body])
          rescue SystemCallError,
                 OpenSSL::SSL::SSLError,
                 HTTPClient::BadResponseError,
                 HTTPClient::TimeoutError => e
            raise MoneyMakerError.new("http error #{e}")
          end

          case response.code
          when 200..201
            return parse_token(response.body)
          when 204
            raise MoneyMakerError.new("204 response no token received")
          else
            raise MoneyMakerError.new("unexpected error #{response.code}")
          end
        end

        def abandon_token(token_id, reason)
          post(token_url(token_id, "abandon"), :abandon_reason => reason)
        end

        def commit_token(token_id)
          post(token_url(token_id, "commit"))
        end

        private

        def parse_token(json)
          raise MoneyMakerError.new("no response body") unless json

          hash = Yajl::Parser.parse(json)
          unless hash["approved"]
            raise MoneyMakerError.new("missing 'approved' entry '#{json}'")
          end

          hash["approved"].downcase!

          unless ["yes", "no"].include?(hash["approved"])
            raise MoneyMakerError.new("malformed 'approved' entry '#{json}'")
          end

          if hash["approved"] == "yes" && hash["token"].nil?
            raise MoneyMakerError.new("missing 'token' entry '#{json}'")
          end

          hash
        end

        def post(url, body = nil)
          request(:post, url, body)
        end

        def put(url, body = nil)
          request(:put, url, body)
        end

        def delete(url, body = nil)
          request(:delete, url, body)
        end

        def request(method, url, body)
          headers = {
            "accept" => :json,
            "x-bs-auth-token" => auth_token
          }
          headers["content-type"] = :json unless body.nil?
          encoded = Yajl::Encoder.encode(body)

          logger.debug "req: #{method} #{url} #{headers} #{body}"
          response = http_client.request(method, url,
                                         :body => encoded,
                                         :header => headers)
          logger.debug "resp: #{response.code} #{response.body}"
          response
        end

        def http_client
          c = HTTPClient.new
          c.send_timeout = http_timeout
          c.receive_timeout = http_timeout
          c.connect_timeout = http_timeout
          c
        end

        def auth_token
          @auth_token
        end

        def quota_manager_url(path)
          "#{@base_url}/#{path}"
        end

        def http_timeout
          @http_timeout
        end

        def token_url(token_id, action)
          quota_manager_url("#{action}/#{token_id}")
        end

        def logger
          QuotaManager.logger
        end
      end
    end
  end
end
