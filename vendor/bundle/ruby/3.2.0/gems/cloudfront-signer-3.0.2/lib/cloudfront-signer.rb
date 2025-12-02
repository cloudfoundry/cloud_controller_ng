# A re-write of https://github.com/stlondemand/aws_cf_signer
#
require 'openssl'
require 'time'
require 'base64'
require 'cloudfront-signer/version'
require 'json'

module Aws
  module CF
    class Signer
      # Public non-inheritable class accessors
      class << self
        # Public: Provides a configuration option to set the key_pair_id if it
        # has not been inferred from the key_path
        #
        # Examples
        #
        #   Aws::CF::Signer.configure do |config|
        #     config.key_pair_id = "XXYYZZ"
        #   end
        #
        # Returns a String value indicating the current setting
        attr_accessor :key_pair_id

        # Public: Provides a configuration option that sets the key_path
        #
        # Examples
        #
        #   Aws::CF::Signer.configure do |config|
        #     config.key_path = "/path/to/your/keyfile.pem"
        #   end
        #
        # Returns nothing.
        def key_path=(path)
          unless File.exist?(path)
            fail ArgumentError,
                 "The signing key could not be found at #{path}"
          end
          @key_path = path
          self.key = File.readlines(path).join('')
        end

        # Public: Provides a configuration option to set the key directly as a
        # string e.g. as an ENV var
        #
        # Examples
        #
        #   Aws::CF::Signer.configure do |config|
        #     config.key = ENV.fetch('KEY')
        #   end
        # Returns nothing.
        def key=(key)
          @key = OpenSSL::PKey::RSA.new(key)
        end

        # Public: Provides an accessor to the key_path
        #
        # Returns a String value indicating the current setting
        attr_reader :key_path

        # Public: Provides a configuration option that sets the default_expires
        # in milliseconds
        #
        # Examples
        #
        #   Aws::CF::Signer.configure do |config|
        #     config.default_expires = 3600
        #   end
        #
        # Returns nothing.
        attr_writer :default_expires

        # Public: Provides an accessor to the default_expires value
        #
        # Returns an Integer value indicating the current setting
        def default_expires
          @default_expires ||= 3600
        end

        private

        # Private: Provides an accessor to the RSA key value
        #
        # Returns an RSA key pair.
        def private_key
          @key
        end
      end

      # Public: Provides a simple way to configure the signing class.
      #
      # Yields self.
      #
      # Examples
      #
      #   Aws::CF::Signer.configure do |config|
      #     config.key_path = "/path/to/yourkeyfile.pem"
      #     config.key_pair_id  = "XXYYZZ"
      #     config.default_expires = 3600
      #   end
      #
      # Returns nothing.
      def self.configure
        yield self if block_given?

        unless key_path || private_key
          fail ArgumentError,
               'You must supply the path to a PEM format RSA key pair.'
        end

        unless @key_pair_id
          @key_pair_id = extract_key_pair_id(key_path)
          fail ArgumentError,
               'The Cloudfront signing key id could not be inferred from ' \
               "#{key_path}. Please supply the key pair id as a " \
               'configuration argument.' unless @key_pair_id
        end
      end

      # Public: Provides a configuration check method which tests to see
      # that the key_path, key_pair_id and private key values have all been set.
      #
      # Returns a Boolean value indicating that settings are present.
      def self.is_configured?
        (key_pair_id.nil? || private_key.nil?) ? false : true
      end

      # Public: Sign a url - encoding any spaces in the url before signing.
      # CloudFront stipulates that signed URLs must not contain spaces (as
      # opposed to stream paths/filenames which CAN contain spaces).
      #
      # Returns a String
      def self.sign_url(subject, policy_options = {})
        build_url subject, { remove_spaces: true }, policy_options
      end

      # Public: Sign a url (as above) and HTML encode the result.
      #
      # Returns a String
      def self.sign_url_safe(subject, policy_options = {})
        build_url subject, { remove_spaces: true, html_escape: true }, policy_options
      end

      # Public: Sign a url (as above) but URI encode the string first.
      #
      # Returns a String
      def self.sign_url_escaped(subject, policy_options = {})
        build_url subject, { uri_escape: true }, policy_options
      end

      # Public: Sign a stream path part or filename (spaces are allowed in
      # stream paths and so are not removed).
      #
      # Returns a String
      def self.sign_path(subject, policy_options = {})
        build_url subject, { remove_spaces: false }, policy_options
      end

      # Public: Sign a stream path or filename and HTML encode the result.
      #
      # Returns a String
      def self.sign_path_safe(subject, policy_options = {})
        build_url subject,
                  { remove_spaces: false, html_escape: true },
                  policy_options
      end

      # Public: Sign a stream path or filename but URI encode the string first
      #
      # Returns a String
      def self.sign_path_escaped(subject, policy_options = {})
        build_url subject, { uri_escape: true }, policy_options
      end

      # Public: Builds a signed url or stream resource name with optional
      # configuration and policy options
      #
      # Returns a String
      def self.build_url(original_subject, configuration_options = {}, policy_options = {})
        subject = original_subject.dup
        # If the url or stream path already has a query string parameter -
        # append to that.
        separator = subject =~ /\?/ ? '&' : '?'

        subject.gsub!(/\s/, '%20') if configuration_options[:remove_spaces]
        subject = URI.escape(subject) if configuration_options[:uri_escape]

        result = subject +
                 separator +
                 signed_params(subject, policy_options).collect do |key, value|
                   "#{key}=#{value}"
                 end.join('&')

        if configuration_options[:html_escape]
          return html_encode(result)
        else
          return result
        end
      end

      # Public: Sign a subject url or stream resource name with optional policy
      # options. It returns raw params to be used in urls or cookies
      #
      # Returns a Hash
      def self.signed_params(subject, policy_options = {})
        result = {}

        if policy_options[:policy_file]
          policy = IO.read(policy_options[:policy_file])
          result['Policy'] = encode_policy(policy)
        else
          policy_options[:expires] = epoch_time(policy_options[:expires] ||
                                                Time.now + default_expires)

          if policy_options.keys.size <= 1
            # Canned Policy - shorter URL
            expires_at = policy_options[:expires]
            policy = %{{"Statement":[{"Resource":"#{subject}","Condition":{"DateLessThan":{"AWS:EpochTime":#{expires_at}}}}]}}
            result['Expires'] = expires_at
          else
            # Custom Policy
            resource = policy_options[:resource] || subject
            policy = generate_custom_policy(resource, policy_options)
            result['Policy'] = encode_policy(policy)
          end
        end

        result.merge 'Signature' => create_signature(policy),
                     'Key-Pair-Id' => @key_pair_id
      end

      private

      def self.generate_custom_policy(resource, options)
        conditions = {
          'DateLessThan' => {
            'AWS:EpochTime' => epoch_time(options[:expires])
          }
        }

        conditions['DateGreaterThan'] = {
          'AWS:EpochTime' => epoch_time(options[:starting])
        } if options[:starting]

        conditions['IpAddress'] = {
          'AWS:SourceIp' => options[:ip_range]
        } if options[:ip_range]

        {
          'Statement' => [{
            'Resource' => resource,
            'Condition' => conditions
          }]
        }.to_json
      end

      def self.epoch_time(timelike)
        case timelike
        when String then Time.parse(timelike).to_i
        when Time   then timelike.to_i
        when Integer then timelike
        else fail ArgumentError,
                  'Invalid argument - String, Integer or Time required - ' \
                  "#{timelike.class} passed."
        end
      end

      def self.encode_policy(policy)
        url_encode Base64.encode64(policy)
      end

      def self.create_signature(policy)
        url_encode Base64.encode64(
          private_key.sign(OpenSSL::Digest::SHA1.new, (policy))
        )
      end

      def self.extract_key_pair_id(key_path)
        File.basename(key_path) =~ /^pk-(.*).pem$/ ? Regexp.last_match[1] : nil
      end

      def self.url_encode(s)
        s.gsub('+', '-').gsub('=', '_').gsub('/', '~').gsub(/\n/, '')
          .gsub(' ', '')
      end

      def self.html_encode(s)
        s.gsub('?', '%3F').gsub('=', '%3D').gsub('&', '%26')
      end
    end
  end
end
