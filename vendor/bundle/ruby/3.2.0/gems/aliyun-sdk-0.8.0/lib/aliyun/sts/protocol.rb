# -*- encoding: utf-8 -*-

require 'rest-client'
require 'nokogiri'
require 'time'

module Aliyun
  module STS

    # Protocol implements the STS Open API which is low-level. User
    # should refer to {STS::Client} for normal use.
    class Protocol

      ENDPOINT = 'https://sts.aliyuncs.com'
      FORMAT = 'XML'
      API_VERSION = '2015-04-01'
      SIGNATURE_METHOD = 'HMAC-SHA1'
      SIGNATURE_VERSION = '1.0'

      include Common::Logging

      def initialize(config)
        @config = config
      end

      # Assume a role
      # @param role [String] the role arn
      # @param session [String] the session name
      # @param policy [STS::Policy] the policy
      # @param duration [Integer] the duration seconds for the
      #  requested token
      # @return [STS::Token] the sts token
      def assume_role(role, session, policy = nil, duration = 3600)
        logger.info("Begin assume role, role: #{role}, session: #{session}, "\
                    "policy: #{policy}, duration: #{duration}")

        params = {
          'Action' => 'AssumeRole',
          'RoleArn' => role,
          'RoleSessionName' => session,
          'DurationSeconds' => duration.to_s
        }
        params.merge!({'Policy' => policy.serialize}) if policy

        body = do_request(params)
        doc = parse_xml(body)

        creds_node = doc.at_css("Credentials")
        creds = {
          session_name: session,
          access_key_id: get_node_text(creds_node, 'AccessKeyId'),
          access_key_secret: get_node_text(creds_node, 'AccessKeySecret'),
          security_token: get_node_text(creds_node, 'SecurityToken'),
          expiration: get_node_text(
            creds_node, 'Expiration') { |x| Time.parse(x) },
        }

        logger.info("Done assume role, creds: #{creds}")

        Token.new(creds)
      end

      private
      # Generate a random signature nonce
      # @return [String] a random string
      def signature_nonce
        (rand * 1_000_000_000).to_s
      end

      # Do HTTP POST request with specified params
      # @param params [Hash] the parameters to STS
      # @return [String] the response body
      # @raise [ServerError] raise errors if the server responds with errors
      def do_request(params)
        query = params.merge(
          {'Format' => FORMAT,
           'Version' => API_VERSION,
           'AccessKeyId' => @config.access_key_id,
           'SignatureMethod' => SIGNATURE_METHOD,
           'SignatureVersion' => SIGNATURE_VERSION,
           'SignatureNonce' => signature_nonce,
           'Timestamp' => Time.now.utc.iso8601})

        signature = Util.get_signature('POST', query, @config.access_key_secret)
        query.merge!({'Signature' => signature})

        r = RestClient::Request.execute(
          :method => 'POST',
          :url => @config.endpoint || ENDPOINT,
          :payload => query
        ) do |response, &blk|

          if response.code >= 300
            e = ServerError.new(response)
            logger.error(e.to_s)
            raise e
          else
            response.return!(&blk)
          end
        end

        logger.debug("Received HTTP response, code: #{r.code}, headers: "\
                     "#{r.headers}, body: #{r.body}")
        r.body
      end

      # Parse body content to xml document
      # @param content [String] the xml content
      # @return [Nokogiri::XML::Document] the parsed document
      def parse_xml(content)
        doc = Nokogiri::XML(content) do |config|
          config.options |= Nokogiri::XML::ParseOptions::NOBLANKS
        end

        doc
      end

      # Get the text of a xml node
      # @param node [Nokogiri::XML::Node] the xml node
      # @param tag [String] the node tag
      # @yield [String] the node text is given to the block
      def get_node_text(node, tag, &block)
        n = node.at_css(tag) if node
        value = n.text if n
        block && value ? yield(value) : value
      end

    end # Protocol
  end # STS
end # Aliyun
