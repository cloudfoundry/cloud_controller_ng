# -*- encoding: utf-8 -*-

require 'rest-client'
require 'nokogiri'
require 'time'

module Aliyun
  module OSS


    ##
    # Protocol implement the OSS Open API which is low-level. User
    # should refer to {OSS::Client} for normal use.
    #
    class Protocol

      STREAM_CHUNK_SIZE = 16 * 1024
      CALLBACK_HEADER = 'x-oss-callback'

      include Common::Logging

      def initialize(config)
        @config = config
        @http = HTTP.new(config)
      end

      # List all the buckets.
      # @param opts [Hash] options
      # @option opts [String] :prefix return only those buckets
      #  prefixed with it if specified
      # @option opts [String] :marker return buckets after where it
      #  indicates (exclusively). All buckets are sorted by name
      #  alphabetically
      # @option opts [Integer] :limit return only the first N
      #  buckets if specified
      # @return [Array<Bucket>, Hash] the returned buckets and a
      #  hash including the next tokens, which includes:
      #  * :prefix [String] the prefix used
      #  * :delimiter [String] the delimiter used
      #  * :marker [String] the marker used
      #  * :limit [Integer] the limit used
      #  * :next_marker [String] marker to continue list buckets
      #  * :truncated [Boolean] whether there are more buckets to
      #    be returned
      def list_buckets(opts = {})
        logger.info("Begin list buckets, options: #{opts}")

        params = {
          'prefix' => opts[:prefix],
          'marker' => opts[:marker],
          'max-keys' => opts[:limit]
        }.reject { |_, v| v.nil? }

        r = @http.get( {}, {:query => params})
        doc = parse_xml(r.body)

        buckets = doc.css("Buckets Bucket").map do |node|
          Bucket.new(
            {
              :name => get_node_text(node, "Name"),
              :location => get_node_text(node, "Location"),
              :creation_time =>
                get_node_text(node, "CreationDate") { |t| Time.parse(t) }
            }, self
          )
        end

        more = {
          :prefix => 'Prefix',
          :limit => 'MaxKeys',
          :marker => 'Marker',
          :next_marker => 'NextMarker',
          :truncated => 'IsTruncated'
        }.reduce({}) { |h, (k, v)|
          value = get_node_text(doc.root, v)
          value.nil?? h : h.merge(k => value)
        }

        update_if_exists(
          more, {
            :limit => ->(x) { x.to_i },
            :truncated => ->(x) { x.to_bool }
          }
        )

        logger.info("Done list buckets, buckets: #{buckets}, more: #{more}")

        [buckets, more]
      end

      # Create a bucket
      # @param name [String] the bucket name
      # @param opts [Hash] options
      # @option opts [String] :location the region where the bucket
      #  is located
      # @example
      #   oss-cn-hangzhou
      def create_bucket(name, opts = {})
        logger.info("Begin create bucket, name: #{name}, opts: #{opts}")

        location = opts[:location]
        body = nil
        if location
          builder = Nokogiri::XML::Builder.new do |xml|
            xml.CreateBucketConfiguration {
              xml.LocationConstraint location
            }
          end
          body = builder.to_xml
        end

        @http.put({:bucket => name}, {:body => body})

        logger.info("Done create bucket")
      end

      # Put bucket acl
      # @param name [String] the bucket name
      # @param acl [String] the bucket acl
      # @see OSS::ACL
      def put_bucket_acl(name, acl)
        logger.info("Begin put bucket acl, name: #{name}, acl: #{acl}")

        sub_res = {'acl' => nil}
        headers = {'x-oss-acl' => acl}
        @http.put(
          {:bucket => name, :sub_res => sub_res},
          {:headers => headers, :body => nil})

        logger.info("Done put bucket acl")
      end

      # Get bucket acl
      # @param name [String] the bucket name
      # @return [String] the acl of this bucket
      def get_bucket_acl(name)
        logger.info("Begin get bucket acl, name: #{name}")

        sub_res = {'acl' => nil}
        r = @http.get({:bucket => name, :sub_res => sub_res})

        doc = parse_xml(r.body)
        acl = get_node_text(doc.at_css("AccessControlList"), 'Grant')
        logger.info("Done get bucket acl")

        acl
      end

      # Put bucket logging settings
      # @param name [String] the bucket name
      # @param logging [BucketLogging] logging options
      def put_bucket_logging(name, logging)
        logger.info("Begin put bucket logging, "\
                    "name: #{name}, logging: #{logging}")

        if logging.enabled? && !logging.target_bucket
          fail ClientError,
               "Must specify target bucket when enabling bucket logging."
        end

        sub_res = {'logging' => nil}
        body = Nokogiri::XML::Builder.new do |xml|
          xml.BucketLoggingStatus {
            if logging.enabled?
              xml.LoggingEnabled {
                xml.TargetBucket logging.target_bucket
                xml.TargetPrefix logging.target_prefix if logging.target_prefix
              }
            end
          }
        end.to_xml

        @http.put(
          {:bucket => name, :sub_res => sub_res},
          {:body => body})

        logger.info("Done put bucket logging")
      end

      # Get bucket logging settings
      # @param name [String] the bucket name
      # @return [BucketLogging] logging options of this bucket
      def get_bucket_logging(name)
        logger.info("Begin get bucket logging, name: #{name}")

        sub_res = {'logging' => nil}
        r = @http.get({:bucket => name, :sub_res => sub_res})

        doc = parse_xml(r.body)
        opts = {:enable => false}

        logging_node = doc.at_css("LoggingEnabled")
        opts.update(
          :target_bucket => get_node_text(logging_node, 'TargetBucket'),
          :target_prefix => get_node_text(logging_node, 'TargetPrefix')
        )
        opts[:enable] = true if opts[:target_bucket]

        logger.info("Done get bucket logging")

        BucketLogging.new(opts)
      end

      # Delete bucket logging settings, a.k.a. disable bucket logging
      # @param name [String] the bucket name
      def delete_bucket_logging(name)
        logger.info("Begin delete bucket logging, name: #{name}")

        sub_res = {'logging' => nil}
        @http.delete({:bucket => name, :sub_res => sub_res})

        logger.info("Done delete bucket logging")
      end

      # Put bucket versioning settings
      # @param name [String] the bucket name
      # @param versioning [BucketVersioning] versioning options
      def put_bucket_versioning(name, versioning)
        logger.info("Begin put bucket versioning, "\
                    "name: #{name}, versioning: #{versioning}")

        sub_res = {'versioning' => nil}
        body = Nokogiri::XML::Builder.new do |xml|
          xml.VersioningConfiguration {
            xml.Status versioning.status
          }
        end.to_xml

        @http.put(
          {:bucket => name, :sub_res => sub_res},
          {:body => body})

        logger.info("Done put bucket versioning")
      end

      # Get bucket versioning settings
      # @param name [String] the bucket name
      # @return [BucketVersioning] versioning options of this bucket
      def get_bucket_versioning(name)
        logger.info("Begin get bucket versioning, name: #{name}")

        sub_res = {'versioning' => nil}
        r = @http.get({:bucket => name, :sub_res => sub_res})

        doc = parse_xml(r.body)

        versioning_node = doc.at_css("VersioningConfiguration")
        opts = {
          :status => get_node_text(versioning_node, 'Status')
        }

        logger.info("Done get bucket versioning")

        BucketVersioning.new(opts)
      end

      # Put bucket encryption settings
      # @param name [String] the bucket name
      # @param encryption [BucketEncryption] encryption options
      def put_bucket_encryption(name, encryption)
        logger.info("Begin put bucket encryption, "\
                    "name: #{name}, encryption: #{encryption}")

        sub_res = {'encryption' => nil}
        body = Nokogiri::XML::Builder.new do |xml|
          xml.ServerSideEncryptionRule {
            xml.ApplyServerSideEncryptionByDefault {
              xml.SSEAlgorithm encryption.sse_algorithm
              xml.KMSMasterKeyID encryption.kms_master_key_id if encryption.kms_master_key_id
            }
          }
        end.to_xml

        @http.put(
          {:bucket => name, :sub_res => sub_res},
          {:body => body})

        logger.info("Done put bucket encryption")
      end

      # Get bucket encryption settings
      # @param name [String] the bucket name
      # @return [BucketEncryption] encryption options of this bucket
      def get_bucket_encryption(name)
        logger.info("Begin get bucket encryption, name: #{name}")

        sub_res = {'encryption' => nil}
        r = @http.get({:bucket => name, :sub_res => sub_res})

        doc = parse_xml(r.body)

        encryption_node = doc.at_css("ApplyServerSideEncryptionByDefault")
        opts = {
          :sse_algorithm => get_node_text(encryption_node, 'SSEAlgorithm'),
          :kms_master_key_id => get_node_text(encryption_node, 'KMSMasterKeyID')
        }

        logger.info("Done get bucket encryption")

        BucketEncryption.new(opts)
      end

      # Delete bucket encryption settings, a.k.a. disable bucket encryption
      # @param name [String] the bucket name
      def delete_bucket_encryption(name)
        logger.info("Begin delete bucket encryption, name: #{name}")

        sub_res = {'encryption' => nil}
        @http.delete({:bucket => name, :sub_res => sub_res})

        logger.info("Done delete bucket encryption")
      end

      # Put bucket website settings
      # @param name [String] the bucket name
      # @param website [BucketWebsite] the bucket website options
      def put_bucket_website(name, website)
        logger.info("Begin put bucket website, "\
                    "name: #{name}, website: #{website}")

        unless website.index
          fail ClientError, "Must specify index to put bucket website."
        end

        sub_res = {'website' => nil}
        body = Nokogiri::XML::Builder.new do |xml|
          xml.WebsiteConfiguration {
            xml.IndexDocument {
              xml.Suffix website.index
            }
            if website.error
              xml.ErrorDocument {
                xml.Key website.error
              }
            end
          }
        end.to_xml

        @http.put(
          {:bucket => name, :sub_res => sub_res},
          {:body => body})

        logger.info("Done put bucket website")
      end

      # Get bucket website settings
      # @param name [String] the bucket name
      # @return [BucketWebsite] the bucket website options
      def get_bucket_website(name)
        logger.info("Begin get bucket website, name: #{name}")

        sub_res = {'website' => nil}
        r = @http.get({:bucket => name, :sub_res => sub_res})

        opts = {:enable => true}
        doc = parse_xml(r.body)
        opts.update(
          :index => get_node_text(doc.at_css('IndexDocument'), 'Suffix'),
          :error => get_node_text(doc.at_css('ErrorDocument'), 'Key')
        )

        logger.info("Done get bucket website")

        BucketWebsite.new(opts)
      end

      # Delete bucket website settings
      # @param name [String] the bucket name
      def delete_bucket_website(name)
        logger.info("Begin delete bucket website, name: #{name}")

        sub_res = {'website' => nil}
        @http.delete({:bucket => name, :sub_res => sub_res})

        logger.info("Done delete bucket website")
      end

      # Put bucket referer
      # @param name [String] the bucket name
      # @param referer [BucketReferer] the bucket referer options
      def put_bucket_referer(name, referer)
        logger.info("Begin put bucket referer, "\
                    "name: #{name}, referer: #{referer}")

        sub_res = {'referer' => nil}
        body = Nokogiri::XML::Builder.new do |xml|
          xml.RefererConfiguration {
            xml.AllowEmptyReferer referer.allow_empty?
            xml.RefererList {
              (referer.whitelist or []).each do |r|
                xml.Referer r
              end
            }
          }
        end.to_xml

        @http.put(
          {:bucket => name, :sub_res => sub_res},
          {:body => body})

        logger.info("Done put bucket referer")
      end

      # Get bucket referer
      # @param name [String] the bucket name
      # @return [BucketReferer] the bucket referer options
      def get_bucket_referer(name)
        logger.info("Begin get bucket referer, name: #{name}")

        sub_res = {'referer' => nil}
        r = @http.get({:bucket => name, :sub_res => sub_res})

        doc = parse_xml(r.body)
        opts = {
          :allow_empty =>
            get_node_text(doc.root, 'AllowEmptyReferer', &:to_bool),
          :whitelist => doc.css("RefererList Referer").map(&:text)
        }

        logger.info("Done get bucket referer")

        BucketReferer.new(opts)
      end

      # Put bucket lifecycle settings
      # @param name [String] the bucket name
      # @param rules [Array<OSS::LifeCycleRule>] the
      #  lifecycle rules
      # @see OSS::LifeCycleRule
      def put_bucket_lifecycle(name, rules)
        logger.info("Begin put bucket lifecycle, name: #{name}, rules: "\
                     "#{rules.map { |r| r.to_s }}")

        sub_res = {'lifecycle' => nil}
        body = Nokogiri::XML::Builder.new do |xml|
          xml.LifecycleConfiguration {
            rules.each do |r|
              xml.Rule {
                xml.ID r.id if r.id
                xml.Status r.enabled? ? 'Enabled' : 'Disabled'

                xml.Prefix r.prefix
                xml.Expiration {
                  if r.expiry.is_a?(Date)
                    xml.Date Time.utc(
                               r.expiry.year, r.expiry.month, r.expiry.day)
                              .iso8601.sub('Z', '.000Z')
                  elsif r.expiry.is_a?(Integer)
                    xml.Days r.expiry
                  else
                    fail ClientError, "Expiry must be a Date or Integer."
                  end
                }
              }
            end
          }
        end.to_xml

        @http.put(
          {:bucket => name, :sub_res => sub_res},
          {:body => body})

        logger.info("Done put bucket lifecycle")
      end

      # Get bucket lifecycle settings
      # @param name [String] the bucket name
      # @return [Array<OSS::LifeCycleRule>] the
      #  lifecycle rules. See {OSS::LifeCycleRule}
      def get_bucket_lifecycle(name)
        logger.info("Begin get bucket lifecycle, name: #{name}")

        sub_res = {'lifecycle' => nil}
        r = @http.get({:bucket => name, :sub_res => sub_res})

        doc = parse_xml(r.body)
        rules = doc.css("Rule").map do |n|
          days = n.at_css("Expiration Days")
          date = n.at_css("Expiration Date")

          if (days && date) || (!days && !date)
            fail ClientError, "We can only have one of Date and Days for expiry."
          end

          LifeCycleRule.new(
            :id => get_node_text(n, 'ID'),
            :prefix => get_node_text(n, 'Prefix'),
            :enable => get_node_text(n, 'Status') { |x| x == 'Enabled' },
            :expiry => days ? days.text.to_i : Date.parse(date.text)
          )
        end
        logger.info("Done get bucket lifecycle")

        rules
      end

      # Delete *all* lifecycle rules on the bucket
      # @note this will delete all lifecycle rules
      # @param name [String] the bucket name
      def delete_bucket_lifecycle(name)
        logger.info("Begin delete bucket lifecycle, name: #{name}")

        sub_res = {'lifecycle' => nil}
        @http.delete({:bucket => name, :sub_res => sub_res})

        logger.info("Done delete bucket lifecycle")
      end

      # Set bucket CORS(Cross-Origin Resource Sharing) rules
      # @param name [String] the bucket name
      # @param rules [Array<OSS::CORSRule] the CORS
      #  rules
      # @see OSS::CORSRule
      def set_bucket_cors(name, rules)
        logger.info("Begin set bucket cors, bucket: #{name}, rules: "\
                     "#{rules.map { |r| r.to_s }.join(';')}")

        sub_res = {'cors' => nil}
        body = Nokogiri::XML::Builder.new do |xml|
          xml.CORSConfiguration {
            rules.each do |r|
              xml.CORSRule {
                r.allowed_origins.each { |x| xml.AllowedOrigin x }
                r.allowed_methods.each { |x| xml.AllowedMethod x }
                r.allowed_headers.each { |x| xml.AllowedHeader x }
                r.expose_headers.each { |x| xml.ExposeHeader x }
                xml.MaxAgeSeconds r.max_age_seconds if r.max_age_seconds
              }
            end
          }
        end.to_xml

        @http.put(
          {:bucket => name, :sub_res => sub_res},
          {:body => body})

        logger.info("Done delete bucket lifecycle")
      end

      # Get bucket CORS rules
      # @param name [String] the bucket name
      # @return [Array<OSS::CORSRule] the CORS rules
      def get_bucket_cors(name)
        logger.info("Begin get bucket cors, bucket: #{name}")

        sub_res = {'cors' => nil}
        r = @http.get({:bucket => name, :sub_res => sub_res})

        doc = parse_xml(r.body)
        rules = []

        doc.css("CORSRule").map do |n|
          allowed_origins = n.css("AllowedOrigin").map(&:text)
          allowed_methods = n.css("AllowedMethod").map(&:text)
          allowed_headers = n.css("AllowedHeader").map(&:text)
          expose_headers = n.css("ExposeHeader").map(&:text)
          max_age_seconds = get_node_text(n, 'MaxAgeSeconds', &:to_i)

          rules << CORSRule.new(
            :allowed_origins => allowed_origins,
            :allowed_methods => allowed_methods,
            :allowed_headers => allowed_headers,
            :expose_headers => expose_headers,
            :max_age_seconds => max_age_seconds)
        end

        logger.info("Done get bucket cors")

        rules
      end

      # Delete all bucket CORS rules
      # @note this will delete all CORS rules of this bucket
      # @param name [String] the bucket name
      def delete_bucket_cors(name)
        logger.info("Begin delete bucket cors, bucket: #{name}")

        sub_res = {'cors' => nil}

        @http.delete({:bucket => name, :sub_res => sub_res})

        logger.info("Done delete bucket cors")
      end

      # Delete a bucket
      # @param name [String] the bucket name
      # @note it will fails if the bucket is not empty (it contains
      #  objects)
      def delete_bucket(name)
        logger.info("Begin delete bucket: #{name}")

        @http.delete({:bucket => name})

        logger.info("Done delete bucket")
      end

      # Put an object to the specified bucket, a block is required
      # to provide the object data.
      # @param bucket_name [String] the bucket name
      # @param object_name [String] the object name
      # @param opts [Hash] Options
      # @option opts [String] :acl specify the object's ACL. See
      #  {OSS::ACL}
      # @option opts [String] :content_type the HTTP Content-Type
      #  for the file, if not specified client will try to determine
      #  the type itself and fall back to HTTP::DEFAULT_CONTENT_TYPE
      #  if it fails to do so
      # @option opts [Hash<Symbol, String>] :metas key-value pairs
      #  that serve as the object meta which will be stored together
      #  with the object
      # @option opts [Callback] :callback the HTTP callback performed
      #  by OSS after `put_object` succeeds
      # @option opts [Hash] :headers custom HTTP headers, case
      #  insensitive. Headers specified here will overwrite `:metas`
      #  and `:content_type`
      # @yield [HTTP::StreamWriter] a stream writer is
      #  yielded to the caller to which it can write chunks of data
      #  streamingly
      # @example
      #   chunk = get_chunk
      #   put_object('bucket', 'object') { |sw| sw.write(chunk) }
      def put_object(bucket_name, object_name, opts = {}, &block)
        logger.debug("Begin put object, bucket: #{bucket_name}, object: "\
                     "#{object_name}, options: #{opts}")

        headers = {'content-type' => opts[:content_type]}
        headers['x-oss-object-acl'] = opts[:acl] if opts.key?(:acl)
        to_lower_case(opts[:metas] || {})
          .each { |k, v| headers["x-oss-meta-#{k.to_s}"] = v.to_s }

        headers.merge!(to_lower_case(opts[:headers])) if opts.key?(:headers)

        if opts.key?(:callback)
          headers[CALLBACK_HEADER] = opts[:callback].serialize
        end

        payload = HTTP::StreamWriter.new(@config.upload_crc_enable, opts[:init_crc], &block)
        r = @http.put(
          {:bucket => bucket_name, :object => object_name},
          {:headers => headers, :body => payload})

        if r.code == 203
          e = CallbackError.new(r)
          logger.error(e.to_s)
          raise e
        end

        if @config.upload_crc_enable && !r.headers[:x_oss_hash_crc64ecma].nil?
          data_crc = payload.data_crc
          Aliyun::OSS::Util.crc_check(data_crc, r.headers[:x_oss_hash_crc64ecma], 'put')
        end

        logger.debug('Done put object')
      end

      # Append to an object of a bucket. Create an "Appendable
      # Object" if the object does not exist. A block is required to
      # provide the appending data.
      # @param bucket_name [String] the bucket name
      # @param object_name [String] the object name
      # @param position [Integer] the position to append
      # @param opts [Hash] Options
      # @option opts [String] :acl specify the object's ACL. See
      #  {OSS::ACL}
      # @option opts [String] :content_type the HTTP Content-Type
      #  for the file, if not specified client will try to determine
      #  the type itself and fall back to HTTP::DEFAULT_CONTENT_TYPE
      #  if it fails to do so
      # @option opts [Hash<Symbol, String>] :metas key-value pairs
      #  that serve as the object meta which will be stored together
      #  with the object
      # @option opts [Hash] :headers custom HTTP headers, case
      #  insensitive. Headers specified here will overwrite `:metas`
      #  and `:content_type`
      # @return [Integer] next position to append
      # @yield [HTTP::StreamWriter] a stream writer is
      #  yielded to the caller to which it can write chunks of data
      #  streamingly
      # @note
      #   1. Can not append to a "Normal Object"
      #   2. The position must equal to the object's size before append
      #   3. The :content_type is only used when the object is created
      def append_object(bucket_name, object_name, position, opts = {}, &block)
        logger.debug("Begin append object, bucket: #{bucket_name}, object: "\
                      "#{object_name}, position: #{position}, options: #{opts}")

        sub_res = {'append' => nil, 'position' => position}
        headers = {'content-type' => opts[:content_type]}
        headers['x-oss-object-acl'] = opts[:acl] if opts.key?(:acl)
        to_lower_case(opts[:metas] || {})
          .each { |k, v| headers["x-oss-meta-#{k.to_s}"] = v.to_s }

        headers.merge!(to_lower_case(opts[:headers])) if opts.key?(:headers)

        payload = HTTP::StreamWriter.new(
          @config.upload_crc_enable && !opts[:init_crc].nil?, opts[:init_crc], &block)

        r = @http.post(
          {:bucket => bucket_name, :object => object_name, :sub_res => sub_res},
          {:headers => headers, :body => payload})

        if @config.upload_crc_enable &&
          !r.headers[:x_oss_hash_crc64ecma].nil? &&
          !opts[:init_crc].nil?
          data_crc = payload.data_crc
          Aliyun::OSS::Util.crc_check(data_crc, r.headers[:x_oss_hash_crc64ecma], 'append')
        end

        logger.debug('Done append object')

        wrap(r.headers[:x_oss_next_append_position], &:to_i) || -1
      end

      # List objects in a bucket.
      # @param bucket_name [String] the bucket name
      # @param opts [Hash] options
      # @option opts [String] :prefix return only those buckets
      #  prefixed with it if specified
      # @option opts [String] :marker return buckets after where it
      #  indicates (exclusively). All buckets are sorted by name
      #  alphabetically
      # @option opts [Integer] :limit return only the first N
      #  buckets if specified
      # @option opts [String] :delimiter the delimiter to get common
      #  prefixes of all objects
      # @option opts [String] :encoding the encoding of object key
      #  in the response body. Only {OSS::KeyEncoding::URL} is
      #  supported now.
      # @example
      #  Assume we have the following objects:
      #     /foo/bar/obj1
      #     /foo/bar/obj2
      #     ...
      #     /foo/bar/obj9999999
      #     /foo/xxx/
      #  use 'foo/' as the prefix, '/' as the delimiter, the common
      #  prefixes we get are: '/foo/bar/', '/foo/xxx/'. They are
      #  coincidentally the sub-directories under '/foo/'. Using
      #  delimiter we avoid list all the objects whose number may be
      #  large.
      # @return [Array<Objects>, Hash] the returned object and a
      #  hash including the next tokens, which includes:
      #  * :common_prefixes [String] the common prefixes returned
      #  * :prefix [String] the prefix used
      #  * :delimiter [String] the delimiter used
      #  * :marker [String] the marker used
      #  * :limit [Integer] the limit used
      #  * :next_marker [String] marker to continue list objects
      #  * :truncated [Boolean] whether there are more objects to
      #    be returned
      def list_objects(bucket_name, opts = {})
        logger.debug("Begin list object, bucket: #{bucket_name}, options: #{opts}")

        params = {
          'prefix' => opts[:prefix],
          'delimiter' => opts[:delimiter],
          'marker' => opts[:marker],
          'max-keys' => opts[:limit],
          'encoding-type' => opts[:encoding]
        }.reject { |_, v| v.nil? }

        r = @http.get({:bucket => bucket_name}, {:query => params})

        doc = parse_xml(r.body)
        encoding = get_node_text(doc.root, 'EncodingType')
        objects = doc.css("Contents").map do |node|
          Object.new(
            :key => get_node_text(node, "Key") { |x| decode_key(x, encoding) },
            :type => get_node_text(node, "Type"),
            :size => get_node_text(node, "Size", &:to_i),
            :etag => get_node_text(node, "ETag"),
            :last_modified =>
              get_node_text(node, "LastModified") { |x| Time.parse(x) }
          )
        end || []

        more = {
          :prefix => 'Prefix',
          :delimiter => 'Delimiter',
          :limit => 'MaxKeys',
          :marker => 'Marker',
          :next_marker => 'NextMarker',
          :truncated => 'IsTruncated',
          :encoding => 'EncodingType'
        }.reduce({}) { |h, (k, v)|
          value = get_node_text(doc.root, v)
          value.nil?? h : h.merge(k => value)
        }

        update_if_exists(
          more, {
            :limit => ->(x) { x.to_i },
            :truncated => ->(x) { x.to_bool },
            :delimiter => ->(x) { decode_key(x, encoding) },
            :marker => ->(x) { decode_key(x, encoding) },
            :next_marker => ->(x) { decode_key(x, encoding) }
          }
        )

        common_prefixes = []
        doc.css("CommonPrefixes Prefix").map do |node|
          common_prefixes << decode_key(node.text, encoding)
        end
        more[:common_prefixes] = common_prefixes unless common_prefixes.empty?

        logger.debug("Done list object. objects: #{objects}, more: #{more}")

        [objects, more]
      end

      # Get an object from the bucket. A block is required to handle
      # the object data chunks.
      # @note User can get the whole object or only part of it by specify
      #  the bytes range;
      # @note User can specify conditions to get the object like:
      #  if-modified-since, if-unmodified-since, if-match-etag,
      #  if-unmatch-etag. If the object to get fails to meet the
      #  conditions, it will not be returned;
      # @note User can indicate the server to rewrite the response headers
      #  such as content-type, content-encoding when get the object
      #  by specify the :rewrite options. The specified headers will
      #  be returned instead of the original property of the object.
      # @param bucket_name [String] the bucket name
      # @param object_name [String] the object name
      # @param opts [Hash] options
      # @option opts [Array<Integer>] :range bytes range to get from
      #  the object, in the format: xx-yy
      # @option opts [Hash] :condition preconditions to get the object
      #   * :if_modified_since (Time) get the object if its modified
      #     time is later than specified
      #   * :if_unmodified_since (Time) get the object if its
      #     unmodified time if earlier than specified
      #   * :if_match_etag (String) get the object if its etag match
      #     specified
      #   * :if_unmatch_etag (String) get the object if its etag
      #     doesn't match specified
      # @option opts [Hash] :headers custom HTTP headers, case
      #  insensitive. Headers specified here will overwrite `:condition`
      #  and `:range`
      # @option opts [Hash] :rewrite response headers to rewrite
      #   * :content_type (String) the Content-Type header
      #   * :content_language (String) the Content-Language header
      #   * :expires (Time) the Expires header
      #   * :cache_control (String) the Cache-Control header
      #   * :content_disposition (String) the Content-Disposition header
      #   * :content_encoding (String) the Content-Encoding header
      # @return [OSS::Object] The object meta
      # @yield [String] it gives the data chunks of the object to
      #  the block
      def get_object(bucket_name, object_name, opts = {}, &block)
        logger.debug("Begin get object, bucket: #{bucket_name}, "\
                     "object: #{object_name}")

        range = opts[:range]
        conditions = opts[:condition]
        rewrites = opts[:rewrite]

        headers = {}
        headers['range'] = get_bytes_range(range) if range
        headers.merge!(get_conditions(conditions)) if conditions
        headers.merge!(to_lower_case(opts[:headers])) if opts.key?(:headers)

        sub_res = {}
        if rewrites
          [ :content_type,
            :content_language,
            :cache_control,
            :content_disposition,
            :content_encoding
          ].each do |k|
            key = "response-#{k.to_s.sub('_', '-')}"
            sub_res[key] = rewrites[k] if rewrites.key?(k)
          end
          sub_res["response-expires"] =
            rewrites[:expires].httpdate if rewrites.key?(:expires)
        end

        data_crc = opts[:init_crc].nil? ? 0 : opts[:init_crc]
        r = @http.get(
          {:bucket => bucket_name, :object => object_name,
           :sub_res => sub_res},
          {:headers => headers}
        ) do |chunk|
          if block_given?
            # crc enable and no range and oss server support crc
            data_crc = Aliyun::OSS::Util.crc(chunk, data_crc) if @config.download_crc_enable && range.nil?
            yield chunk
          end
        end

        if @config.download_crc_enable && range.nil? && !r.headers[:x_oss_hash_crc64ecma].nil?
          Aliyun::OSS::Util.crc_check(data_crc, r.headers[:x_oss_hash_crc64ecma], 'get')
        end

        h = r.headers
        metas = {}
        meta_prefix = 'x_oss_meta_'
        h.select { |k, _| k.to_s.start_with?(meta_prefix) }
          .each { |k, v| metas[k.to_s.sub(meta_prefix, '')] = v.to_s }

        obj = Object.new(
          :key => object_name,
          :type => h[:x_oss_object_type],
          :size => wrap(h[:content_length], &:to_i),
          :etag => h[:etag],
          :metas => metas,
          :last_modified => wrap(h[:last_modified]) { |x| Time.parse(x) },
          :headers => h)

        logger.debug("Done get object")

        obj
      end

      # Get the object meta rather than the whole object.
      # @note User can specify conditions to get the object like:
      #  if-modified-since, if-unmodified-since, if-match-etag,
      #  if-unmatch-etag. If the object to get fails to meet the
      #  conditions, it will not be returned.
      #
      # @param bucket_name [String] the bucket name
      # @param object_name [String] the object name
      # @param opts [Hash] options
      # @option opts [Hash] :condition preconditions to get the
      #  object meta. The same as #get_object
      # @return [OSS::Object] The object meta
      def get_object_meta(bucket_name, object_name, opts = {})
        logger.debug("Begin get object meta, bucket: #{bucket_name}, "\
                     "object: #{object_name}, options: #{opts}")

        headers = {}
        headers.merge!(get_conditions(opts[:condition])) if opts[:condition]

        r = @http.head(
          {:bucket => bucket_name, :object => object_name},
          {:headers => headers})

        h = r.headers
        metas = {}
        meta_prefix = 'x_oss_meta_'
        h.select { |k, _| k.to_s.start_with?(meta_prefix) }
          .each { |k, v| metas[k.to_s.sub(meta_prefix, '')] = v.to_s }

        obj = Object.new(
          :key => object_name,
          :type => h[:x_oss_object_type],
          :size => wrap(h[:content_length], &:to_i),
          :etag => h[:etag],
          :metas => metas,
          :last_modified => wrap(h[:last_modified]) { |x| Time.parse(x) },
          :headers => h)

        logger.debug("Done get object meta")

        obj
      end

      # Copy an object in the bucket. The source object and the dest
      # object may be from different buckets of the same region.
      # @param bucket_name [String] the bucket name
      # @param src_object_name [String] the source object name
      # @param dst_object_name [String] the dest object name
      # @param opts [Hash] options
      # @option opts [String] :src_bucket specify the source object's
      #  bucket. It MUST be in the same region as the dest bucket. It
      #  defaults to dest bucket if not specified.
      # @option opts [String] :acl specify the dest object's
      #  ACL. See {OSS::ACL}
      # @option opts [String] :meta_directive specify what to do
      #  with the object's meta: copy or replace. See
      #  {OSS::MetaDirective}
      # @option opts [String] :content_type the HTTP Content-Type
      #  for the file, if not specified client will try to determine
      #  the type itself and fall back to HTTP::DEFAULT_CONTENT_TYPE
      #  if it fails to do so
      # @option opts [Hash<Symbol, String>] :metas key-value pairs
      #  that serve as the object meta which will be stored together
      #  with the object
      # @option opts [Hash] :condition preconditions to get the
      #  object. See #get_object
      # @return [Hash] the copy result
      #  * :etag [String] the etag of the dest object
      #  * :last_modified [Time] the last modification time of the
      #    dest object
      def copy_object(bucket_name, src_object_name, dst_object_name, opts = {})
        logger.debug("Begin copy object, bucket: #{bucket_name}, "\
                     "source object: #{src_object_name}, dest object: "\
                     "#{dst_object_name}, options: #{opts}")

        src_bucket = opts[:src_bucket] || bucket_name
        headers = {
          'x-oss-copy-source' =>
            @http.get_resource_path(src_bucket, src_object_name),
          'content-type' => opts[:content_type]
        }
        (opts[:metas] || {})
          .each { |k, v| headers["x-oss-meta-#{k.to_s}"] = v.to_s }

        {
          :acl => 'x-oss-object-acl',
          :meta_directive => 'x-oss-metadata-directive'
        }.each { |k, v| headers[v] = opts[k] if opts[k] }

        headers.merge!(get_copy_conditions(opts[:condition])) if opts[:condition]

        r = @http.put(
          {:bucket => bucket_name, :object => dst_object_name},
          {:headers => headers})

        doc = parse_xml(r.body)
        copy_result = {
          :last_modified => get_node_text(
            doc.root, 'LastModified') { |x| Time.parse(x) },
          :etag => get_node_text(doc.root, 'ETag')
        }.reject { |_, v| v.nil? }

        logger.debug("Done copy object")

        copy_result
      end

      # Delete an object from the bucket
      # @param bucket_name [String] the bucket name
      # @param object_name [String] the object name
      def delete_object(bucket_name, object_name)
        logger.debug("Begin delete object, bucket: #{bucket_name}, "\
                     "object:  #{object_name}")

        @http.delete({:bucket => bucket_name, :object => object_name})

        logger.debug("Done delete object")
      end

      # Batch delete objects
      # @param bucket_name [String] the bucket name
      # @param object_names [Enumerator<String>] the object names
      # @param opts [Hash] options
      # @option opts [Boolean] :quiet indicates whether the server
      #  should return the delete result of the objects
      # @option opts [String] :encoding the encoding type for
      #  object key in the response body, only
      #  {OSS::KeyEncoding::URL} is supported now
      # @return [Array<String>] object names that have been
      #  successfully deleted or empty if :quiet is true
      def batch_delete_objects(bucket_name, object_names, opts = {})
        logger.debug("Begin batch delete object, bucket: #{bucket_name}, "\
                     "objects: #{object_names}, options: #{opts}")

        sub_res = {'delete' => nil}

        # It may have invisible chars in object key which will corrupt
        # libxml. So we're constructing xml body manually here.
        body = '<?xml version="1.0"?>'
        body << '<Delete>'
        body << '<Quiet>' << (opts[:quiet]? true : false).to_s << '</Quiet>'
        object_names.each { |k|
          body << '<Object><Key>' << CGI.escapeHTML(k) << '</Key></Object>'
        }
        body << '</Delete>'

        query = {}
        query['encoding-type'] = opts[:encoding] if opts[:encoding]

        r = @http.post(
             {:bucket => bucket_name, :sub_res => sub_res},
             {:query => query, :body => body})

        deleted = []
        unless opts[:quiet]
          doc = parse_xml(r.body)
          encoding = get_node_text(doc.root, 'EncodingType')
          doc.css("Deleted").map do |n|
            deleted << get_node_text(n, 'Key') { |x| decode_key(x, encoding) }
          end
        end

        logger.debug("Done delete object")

        deleted
      end

      # Put object acl
      # @param bucket_name [String] the bucket name
      # @param object_name [String] the object name
      # @param acl [String] the object's ACL. See {OSS::ACL}
      def put_object_acl(bucket_name, object_name, acl)
        logger.debug("Begin update object acl, bucket: #{bucket_name}, "\
                     "object: #{object_name}, acl: #{acl}")

        sub_res = {'acl' => nil}
        headers = {'x-oss-object-acl' => acl}

        @http.put(
          {:bucket => bucket_name, :object => object_name, :sub_res => sub_res},
          {:headers => headers})

        logger.debug("Done update object acl")
      end

      # Get object acl
      # @param bucket_name [String] the bucket name
      # @param object_name [String] the object name
      # [return] the object's acl. See {OSS::ACL}
      def get_object_acl(bucket_name, object_name)
        logger.debug("Begin get object acl, bucket: #{bucket_name}, "\
                     "object: #{object_name}")

        sub_res = {'acl' => nil}
        r = @http.get(
          {bucket: bucket_name, object: object_name, sub_res: sub_res})

        doc = parse_xml(r.body)
        acl = get_node_text(doc.at_css("AccessControlList"), 'Grant')

        logger.debug("Done get object acl")

        acl
      end

      # Get object CORS rule
      # @note this is usually used by browser to make a "preflight"
      # @param bucket_name [String] the bucket name
      # @param object_name [String] the object name
      # @param origin [String] the Origin of the reqeust
      # @param method [String] the method to request access:
      #  Access-Control-Request-Method
      # @param headers [Array<String>] the headers to request access:
      #  Access-Control-Request-Headers
      # @return [CORSRule] the CORS rule of the object
      def get_object_cors(bucket_name, object_name, origin, method, headers = [])
        logger.debug("Begin get object cors, bucket: #{bucket_name}, object: "\
                     "#{object_name}, origin: #{origin}, method: #{method}, "\
                     "headers: #{headers.join(',')}")

        h = {
          'origin' => origin,
          'access-control-request-method' => method,
          'access-control-request-headers' => headers.join(',')
        }

        r = @http.options(
          {:bucket => bucket_name, :object => object_name},
          {:headers => h})

        logger.debug("Done get object cors")

        CORSRule.new(
          :allowed_origins => r.headers[:access_control_allow_origin],
          :allowed_methods => r.headers[:access_control_allow_methods],
          :allowed_headers => r.headers[:access_control_allow_headers],
          :expose_headers => r.headers[:access_control_expose_headers],
          :max_age_seconds => r.headers[:access_control_max_age]
        )
      end

      ##
      # Multipart uploading
      #

      # Initiate a a multipart uploading transaction
      # @param bucket_name [String] the bucket name
      # @param object_name [String] the object name
      # @param opts [Hash] options
      # @option opts [String] :content_type the HTTP Content-Type
      #  for the file, if not specified client will try to determine
      #  the type itself and fall back to HTTP::DEFAULT_CONTENT_TYPE
      #  if it fails to do so
      # @option opts [Hash<Symbol, String>] :metas key-value pairs
      #  that serve as the object meta which will be stored together
      #  with the object
      # @option opts [Hash] :headers custom HTTP headers, case
      #  insensitive. Headers specified here will overwrite `:metas`
      #  and `:content_type`
      # @return [String] the upload id
      def initiate_multipart_upload(bucket_name, object_name, opts = {})
        logger.info("Begin initiate multipart upload, bucket: "\
                    "#{bucket_name}, object: #{object_name}, options: #{opts}")

        sub_res = {'uploads' => nil}
        headers = {'content-type' => opts[:content_type]}
        to_lower_case(opts[:metas] || {})
          .each { |k, v| headers["x-oss-meta-#{k.to_s}"] = v.to_s }

        headers.merge!(to_lower_case(opts[:headers])) if opts.key?(:headers)

        r = @http.post(
          {:bucket => bucket_name, :object => object_name,
           :sub_res => sub_res},
          {:headers => headers})

        doc = parse_xml(r.body)
        txn_id = get_node_text(doc.root, 'UploadId')

        logger.info("Done initiate multipart upload: #{txn_id}.")

        txn_id
      end

      # Upload a part in a multipart uploading transaction.
      # @param bucket_name [String] the bucket name
      # @param object_name [String] the object name
      # @param txn_id [String] the upload id
      # @param part_no [Integer] the part number
      # @yield [HTTP::StreamWriter] a stream writer is
      #  yielded to the caller to which it can write chunks of data
      #  streamingly
      def upload_part(bucket_name, object_name, txn_id, part_no, &block)
        logger.debug("Begin upload part, bucket: #{bucket_name}, object: "\
                     "#{object_name}, txn id: #{txn_id}, part No: #{part_no}")

        sub_res = {'partNumber' => part_no, 'uploadId' => txn_id}

        payload = HTTP::StreamWriter.new(@config.upload_crc_enable, &block)
        r = @http.put(
          {:bucket => bucket_name, :object => object_name, :sub_res => sub_res},
          {:body => payload})

        if @config.upload_crc_enable && !r.headers[:x_oss_hash_crc64ecma].nil?
          data_crc = payload.data_crc
          Aliyun::OSS::Util.crc_check(data_crc, r.headers[:x_oss_hash_crc64ecma], 'put')
        end

        logger.debug("Done upload part")

        Multipart::Part.new(:number => part_no, :etag => r.headers[:etag])
      end

      # Upload a part in a multipart uploading transaction by copying
      # from an existent object as the part's content. It may copy
      # only part of the object by specifying the bytes range to read.
      # @param bucket_name [String] the bucket name
      # @param object_name [String] the object name
      # @param txn_id [String] the upload id
      # @param part_no [Integer] the part number
      # @param source_object [String] the source object name to copy from
      # @param opts [Hash] options
      # @option opts [String] :src_bucket specify the source object's
      #  bucket. It MUST be in the same region as the dest bucket. It
      #  defaults to dest bucket if not specified.
      # @option opts [Array<Integer>] :range the bytes range to
      #  copy, int the format: [begin(inclusive), end(exclusive)]
      # @option opts [Hash] :condition preconditions to copy the
      #  object. See #get_object
      def upload_part_by_copy(
            bucket_name, object_name, txn_id, part_no, source_object, opts = {})
        logger.debug("Begin upload part by copy, bucket: #{bucket_name}, "\
                     "object: #{object_name}, source object: #{source_object}"\
                     "txn id: #{txn_id}, part No: #{part_no}, options: #{opts}")

        range = opts[:range]
        conditions = opts[:condition]

        if range && (!range.is_a?(Array) || range.size != 2)
          fail ClientError, "Range must be an array containing 2 Integers."
        end

        src_bucket = opts[:src_bucket] || bucket_name
        headers = {
          'x-oss-copy-source' =>
            @http.get_resource_path(src_bucket, source_object)
        }
        headers['range'] = get_bytes_range(range) if range
        headers.merge!(get_copy_conditions(conditions)) if conditions

        sub_res = {'partNumber' => part_no, 'uploadId' => txn_id}

        r = @http.put(
          {:bucket => bucket_name, :object => object_name, :sub_res => sub_res},
          {:headers => headers})

        logger.debug("Done upload part by copy: #{source_object}.")

        Multipart::Part.new(:number => part_no, :etag => r.headers[:etag])
      end

      # Complete a multipart uploading transaction
      # @param bucket_name [String] the bucket name
      # @param object_name [String] the object name
      # @param txn_id [String] the upload id
      # @param parts [Array<Multipart::Part>] all the parts in this
      #  transaction
      # @param callback [Callback] the HTTP callback performed by OSS
      #  after this operation succeeds
      def complete_multipart_upload(
            bucket_name, object_name, txn_id, parts, callback = nil)
        logger.debug("Begin complete multipart upload, "\
                     "txn id: #{txn_id}, parts: #{parts.map(&:to_s)}")

        sub_res = {'uploadId' => txn_id}
        headers = {}
        headers[CALLBACK_HEADER] = callback.serialize if callback

        body = Nokogiri::XML::Builder.new do |xml|
          xml.CompleteMultipartUpload {
            parts.each do |p|
              xml.Part {
                xml.PartNumber p.number
                xml.ETag p.etag
              }
            end
          }
        end.to_xml

        r = @http.post(
          {:bucket => bucket_name, :object => object_name, :sub_res => sub_res},
          {:headers => headers, :body => body})

        if r.code == 203
          e = CallbackError.new(r)
          logger.error(e.to_s)
          raise e
        end

        logger.debug("Done complete multipart upload: #{txn_id}.")
      end

      # Abort a multipart uploading transaction
      # @note All the parts are discarded after abort. For some parts
      #  being uploaded while the abort happens, they may not be
      #  discarded. Call abort_multipart_upload several times for this
      #  situation.
      # @param bucket_name [String] the bucket name
      # @param object_name [String] the object name
      # @param txn_id [String] the upload id
      def abort_multipart_upload(bucket_name, object_name, txn_id)
        logger.debug("Begin abort multipart upload, txn id: #{txn_id}")

        sub_res = {'uploadId' => txn_id}

        @http.delete(
          {:bucket => bucket_name, :object => object_name, :sub_res => sub_res})

        logger.debug("Done abort multipart: #{txn_id}.")
      end

      # Get a list of all the on-going multipart uploading
      # transactions. That is: thoses started and not aborted.
      # @param bucket_name [String] the bucket name
      # @param opts [Hash] options:
      # @option opts [String] :id_marker return only thoese
      #  transactions with txn id after :id_marker
      # @option opts [String] :key_marker the object key marker for
      #  a multipart upload transaction.
      #  1. if +:id_marker+ is not set, return only those
      #     transactions with object key *after* +:key_marker+;
      #  2. if +:id_marker+ is set, return only thoese transactions
      #     with object key *equals* +:key_marker+ and txn id after
      #     +:id_marker+
      # @option opts [String] :prefix the prefix of the object key
      #  for a multipart upload transaction. if set only return
      #  those transactions with the object key prefixed with it
      # @option opts [String] :encoding the encoding of object key
      #  in the response body. Only {OSS::KeyEncoding::URL} is
      #  supported now.
      # @return [Array<Multipart::Transaction>, Hash]
      #  the returned transactions and a hash including next tokens,
      #  which includes:
      #  * :prefix [String] the prefix used
      #  * :limit [Integer] the limit used
      #  * :id_marker [String] the upload id marker used
      #  * :next_id_marker [String] upload id marker to continue list
      #    multipart transactions
      #  * :key_marker [String] the object key marker used
      #  * :next_key_marker [String] object key marker to continue
      #    list multipart transactions
      #  * :truncated [Boolean] whether there are more transactions
      #    to be returned
      #  * :encoding [String] the object key encoding used
      def list_multipart_uploads(bucket_name, opts = {})
        logger.debug("Begin list multipart uploads, "\
                     "bucket: #{bucket_name}, opts: #{opts}")

        sub_res = {'uploads' => nil}
        params = {
          'prefix' => opts[:prefix],
          'upload-id-marker' => opts[:id_marker],
          'key-marker' => opts[:key_marker],
          'max-uploads' => opts[:limit],
          'encoding-type' => opts[:encoding]
        }.reject { |_, v| v.nil? }

        r = @http.get(
          {:bucket => bucket_name, :sub_res => sub_res},
          {:query => params})

        doc = parse_xml(r.body)
        encoding = get_node_text(doc.root, 'EncodingType')
        txns = doc.css("Upload").map do |node|
          Multipart::Transaction.new(
            :id => get_node_text(node, "UploadId"),
            :object => get_node_text(node, "Key") { |x| decode_key(x, encoding) },
            :bucket => bucket_name,
            :creation_time =>
              get_node_text(node, "Initiated") { |t| Time.parse(t) }
          )
        end || []

        more = {
          :prefix => 'Prefix',
          :limit => 'MaxUploads',
          :id_marker => 'UploadIdMarker',
          :next_id_marker => 'NextUploadIdMarker',
          :key_marker => 'KeyMarker',
          :next_key_marker => 'NextKeyMarker',
          :truncated => 'IsTruncated',
          :encoding => 'EncodingType'
        }.reduce({}) { |h, (k, v)|
          value = get_node_text(doc.root, v)
          value.nil?? h : h.merge(k => value)
        }

        update_if_exists(
          more, {
            :limit => ->(x) { x.to_i },
            :truncated => ->(x) { x.to_bool },
            :key_marker => ->(x) { decode_key(x, encoding) },
            :next_key_marker => ->(x) { decode_key(x, encoding) }
          }
        )

        logger.debug("Done list multipart transactions")

        [txns, more]
      end

      # Get a list of parts that are successfully uploaded in a
      # transaction.
      # @param txn_id [String] the upload id
      # @param opts [Hash] options:
      # @option opts [Integer] :marker the part number marker after
      #  which to return parts
      # @option opts [Integer] :limit max number parts to return
      # @return [Array<Multipart::Part>, Hash] the returned parts and
      #  a hash including next tokens, which includes:
      #  * :marker [Integer] the marker used
      #  * :limit [Integer] the limit used
      #  * :next_marker [Integer] marker to continue list parts
      #  * :truncated [Boolean] whether there are more parts to be
      #    returned
      def list_parts(bucket_name, object_name, txn_id, opts = {})
        logger.debug("Begin list parts, bucket: #{bucket_name}, object: "\
                     "#{object_name}, txn id: #{txn_id}, options: #{opts}")

        sub_res = {'uploadId' => txn_id}
        params = {
          'part-number-marker' => opts[:marker],
          'max-parts' => opts[:limit],
          'encoding-type' => opts[:encoding]
        }.reject { |_, v| v.nil? }

        r = @http.get(
          {:bucket => bucket_name, :object => object_name, :sub_res => sub_res},
          {:query => params})

        doc = parse_xml(r.body)
        parts = doc.css("Part").map do |node|
          Multipart::Part.new(
            :number => get_node_text(node, 'PartNumber', &:to_i),
            :etag => get_node_text(node, 'ETag'),
            :size => get_node_text(node, 'Size', &:to_i),
            :last_modified =>
              get_node_text(node, 'LastModified') { |x| Time.parse(x) })
        end || []

        more = {
          :limit => 'MaxParts',
          :marker => 'PartNumberMarker',
          :next_marker => 'NextPartNumberMarker',
          :truncated => 'IsTruncated',
          :encoding => 'EncodingType'
        }.reduce({}) { |h, (k, v)|
          value = get_node_text(doc.root, v)
          value.nil?? h : h.merge(k => value)
        }

        update_if_exists(
          more, {
            :limit => ->(x) { x.to_i },
            :truncated => ->(x) { x.to_bool }
          }
        )

        logger.debug("Done list parts, parts: #{parts}, more: #{more}")

        [parts, more]
      end

      # Get bucket/object url
      # @param [String] bucket the bucket name
      # @param [String] object the bucket name
      # @return [String] url for the bucket/object
      def get_request_url(bucket, object = nil)
        @http.get_request_url(bucket, object)
      end

      # Get bucket/object resource path
      # @param [String] bucket the bucket name
      # @param [String] object the bucket name
      # @return [String] resource path for the bucket/object
      def get_resource_path(bucket, object = nil)
        @http.get_resource_path(bucket, object)
      end

      # Get user's access key id
      # @return [String] the access key id
      def get_access_key_id
        @config.access_key_id
      end

      # Get user's access key secret
      # @return [String] the access key secret
      def get_access_key_secret
        @config.access_key_secret
      end  

      # Get user's STS token
      # @return [String] the STS token
      def get_sts_token
        @config.sts_token
      end

      # Sign a string using the stored access key secret
      # @param [String] string_to_sign the string to sign
      # @return [String] the signature
      def sign(string_to_sign)
        Util.sign(@config.access_key_secret, string_to_sign)
      end

      # Get the download crc status
      # @return true(download crc enable) or false(download crc disable)
      def download_crc_enable
        @config.download_crc_enable
      end

      # Get the upload crc status
      # @return true(upload crc enable) or false(upload crc disable)
      def upload_crc_enable
        @config.upload_crc_enable
      end

      private

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

      # Decode object key using encoding. If encoding is nil it
      # returns the key directly.
      # @param key [String] the object key
      # @param encoding [String] the encoding used
      # @return [String] the decoded key
      def decode_key(key, encoding)
        return key unless encoding

        unless KeyEncoding.include?(encoding)
          fail ClientError, "Unsupported key encoding: #{encoding}"
        end

        if encoding == KeyEncoding::URL
          return CGI.unescape(key)
        end
      end

      # Transform x if x is not nil
      # @param x [Object] the object to transform
      # @yield [Object] the object if given to the block
      # @return [Object] the transformed object
      def wrap(x, &block)
        yield x if x
      end

      # Get conditions for HTTP headers
      # @param conditions [Hash] the conditions
      # @return [Hash] conditions for HTTP headers
      def get_conditions(conditions)
        {
          :if_modified_since => 'if-modified-since',
          :if_unmodified_since => 'if-unmodified-since',
        }.reduce({}) { |h, (k, v)|
          conditions.key?(k)? h.merge(v => conditions[k].httpdate) : h
        }.merge(
          {
            :if_match_etag => 'if-match',
            :if_unmatch_etag => 'if-none-match'
          }.reduce({}) { |h, (k, v)|
            conditions.key?(k)? h.merge(v => conditions[k]) : h
          }
        )
      end

      # Get copy conditions for HTTP headers
      # @param conditions [Hash] the conditions
      # @return [Hash] copy conditions for HTTP headers
      def get_copy_conditions(conditions)
        {
          :if_modified_since => 'x-oss-copy-source-if-modified-since',
          :if_unmodified_since => 'x-oss-copy-source-if-unmodified-since',
        }.reduce({}) { |h, (k, v)|
          conditions.key?(k)? h.merge(v => conditions[k].httpdate) : h
        }.merge(
          {
            :if_match_etag => 'x-oss-copy-source-if-match',
            :if_unmatch_etag => 'x-oss-copy-source-if-none-match'
          }.reduce({}) { |h, (k, v)|
            conditions.key?(k)? h.merge(v => conditions[k]) : h
          }
        )
      end

      # Get bytes range
      # @param range [Array<Integer>] range
      # @return [String] bytes range for HTTP headers
      def get_bytes_range(range)
        if range &&
           (!range.is_a?(Array) || range.size != 2 ||
            !range.at(0).is_a?(Integer) || !range.at(1).is_a?(Integer))
          fail ClientError, "Range must be an array containing 2 Integers."
        end

        "bytes=#{range.at(0)}-#{range.at(1) - 1}"
      end

      # Update values for keys that exist in hash
      # @param hash [Hash] the hash to be updated
      # @param kv [Hash] keys & blocks to updated
      def update_if_exists(hash, kv)
        kv.each { |k, v| hash[k] = v.call(hash[k]) if hash.key?(k) }
      end

      # Convert hash keys to lower case Non-Recursively
      # @param hash [Hash] the hash to be converted
      # @return [Hash] hash with lower case keys
      def to_lower_case(hash)
        hash.reduce({}) do |result, (k, v)|
          result[k.to_s.downcase] = v
          result
        end
      end
    end # Protocol
  end # OSS
end # Aliyun
