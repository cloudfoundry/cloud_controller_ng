# Copyright (c) 2009-2012 VMware, Inc.

require "httpclient"

module VCAP::CloudController::RestController
  module QuotaManager
    class << self
      def configure(config)
        c = config[:quota_manager]
        policy = c[:policy] || "MoneyMaker"
        @policy = QuotaManager.const_get(policy)
        MoneyMakerClient.configure(c)
      end

      def fetch_quota_token(quota_request)
        p = quota_request ? policy : BlindApproval
        logger.debug "policy: #{p}"
        token = p.fetch_quota_token(quota_request)
        unless token.approved?
          raise VCAP::CloudController::Errors::QuotaDeclined.new(token.reason)
        end
        logger.debug "token: #{token.inspect}"
        token
      end

      def policy
        @policy
      end

      def logger
        @logger ||= VCAP::Logging.logger("cc.qm")
      end
    end

    class BlindApprovalToken
      def abandon(reason)
        logger.debug "blind abandon: #{reason}"
      end

      def commit
        logger.debug "blind commit"
      end

      def approved?
        true
      end

      def reason
      end

      private

      def logger
        QuotaManager.logger
      end
    end

    class BlindApproval
      def self.fetch_quota_token(quota_request)
        BlindApprovalToken.new
      end
    end

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
            :accept => :json,
            :x_bs_auth_token => auth_token
          }
          headers[:content_type] = :json unless body.nil?
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
