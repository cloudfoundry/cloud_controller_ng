# -*- encoding: utf-8 -*-

module Aliyun
  module OSS
    ##
    # Bucket是用户的Object相关的操作的client，主要包括三部分功能：
    # 1. bucket相关：获取/设置bucket的属性（acl, logging, referer,
    #    website, lifecycle, cors）
    # 2. object相关：上传、下载、追加、拷贝object等
    # 3. multipart相关：断点续传、断点续载
    class Bucket < Common::Struct::Base

      attrs :name, :location, :creation_time

      def initialize(opts = {}, protocol = nil)
        super(opts)
        @protocol = protocol
      end

      ### Bucket相关的API ###

      # 获取Bucket的ACL
      # @return [String] Bucket的{OSS::ACL ACL}
      def acl
        @protocol.get_bucket_acl(name)
      end

      # 设置Bucket的ACL
      # @param acl [String] Bucket的{OSS::ACL ACL}
      def acl=(acl)
        @protocol.put_bucket_acl(name, acl)
      end

      # 获取Bucket的logging配置
      # @return [BucketLogging] Bucket的logging配置
      def logging
        @protocol.get_bucket_logging(name)
      end

      # 设置Bucket的logging配置
      # @param logging [BucketLogging] logging配置
      def logging=(logging)
        if logging.enabled?
          @protocol.put_bucket_logging(name, logging)
        else
          @protocol.delete_bucket_logging(name)
        end
      end

      # 获取Bucket的versioning配置
      # @return [BucketVersioning] Bucket的versioning配置
      def versioning
        @protocol.get_bucket_versioning(name)
      end

      # 设置Bucket的versioning配置
      # @param versioning [BucketVersioning] versioning配置
      def versioning=(versioning)
          @protocol.put_bucket_versioning(name, versioning)
      end

      # 获取Bucket的encryption配置
      # @return [BucketEncryption] Bucket的encryption配置
      def encryption
        @protocol.get_bucket_encryption(name)
      end

      # 设置Bucket的encryption配置
      # @param encryption [BucketEncryption] encryption配置
      def encryption=(encryption)
        if encryption.enabled?
          @protocol.put_bucket_encryption(name, encryption)
        else
          @protocol.delete_bucket_encryption(name)
        end
      end

      # 获取Bucket的website配置
      # @return [BucketWebsite] Bucket的website配置
      def website
        begin
          w = @protocol.get_bucket_website(name)
        rescue ServerError => e
          raise unless e.http_code == 404
        end

        w || BucketWebsite.new
      end

      # 设置Bucket的website配置
      # @param website [BucketWebsite] website配置
      def website=(website)
        if website.enabled?
          @protocol.put_bucket_website(name, website)
        else
          @protocol.delete_bucket_website(name)
        end
      end

      # 获取Bucket的Referer配置
      # @return [BucketReferer] Bucket的Referer配置
      def referer
        @protocol.get_bucket_referer(name)
      end

      # 设置Bucket的Referer配置
      # @param referer [BucketReferer] Referer配置
      def referer=(referer)
        @protocol.put_bucket_referer(name, referer)
      end

      # 获取Bucket的生命周期配置
      # @return [Array<OSS::LifeCycleRule>] Bucket的生命周期规则，如果
      #  当前Bucket未设置lifecycle，则返回[]
      def lifecycle
        begin
          r = @protocol.get_bucket_lifecycle(name)
        rescue ServerError => e
          raise unless e.http_code == 404
        end

        r || []
      end

      # 设置Bucket的生命周期配置
      # @param rules [Array<OSS::LifeCycleRule>] 生命
      #  周期配置规则
      # @see OSS::LifeCycleRule 查看如何设置生命周期规则
      # @note 如果rules为空，则会删除这个bucket上的lifecycle配置
      def lifecycle=(rules)
        if rules.empty?
          @protocol.delete_bucket_lifecycle(name)
        else
          @protocol.put_bucket_lifecycle(name, rules)
        end
      end

      # 获取Bucket的跨域资源共享(CORS)的规则
      # @return [Array<OSS::CORSRule>] Bucket的CORS规则，如果当前
      #  Bucket未设置CORS规则，则返回[]
      def cors
        begin
          r = @protocol.get_bucket_cors(name)
        rescue ServerError => e
          raise unless e.http_code == 404
        end

        r || []
      end

      # 设置Bucket的跨域资源共享(CORS)的规则
      # @param rules [Array<OSS::CORSRule>] CORS规则
      # @note 如果rules为空，则会删除这个bucket上的CORS配置
      def cors=(rules)
        if rules.empty?
          @protocol.delete_bucket_cors(name)
        else
          @protocol.set_bucket_cors(name, rules)
        end
      end

      ### Object相关的API ###


      # 列出bucket中的object
      # @param opts [Hash] 查询选项
      # @option opts [String] :prefix 返回的object的前缀，如果设置则只
      #  返回那些名字以它为前缀的object
      # @option opts [String] :marker 如果设置，则只返回名字在它之后
      #  （字典序，不包含marker）的object
      # @option opts [String] :delimiter 用于获取公共前缀的分隔符，从
      #  前缀后面开始到第一个分隔符出现的位置之前的字符，作为公共前缀。
      # @example
      #  假设我们有如下objects:
      #     /foo/bar/obj1
      #     /foo/bar/obj2
      #     ...
      #     /foo/bar/obj9999999
      #     /foo/xxx/
      #  用'foo/'作为前缀, '/'作为分隔符, 则得到的公共前缀是：
      #  '/foo/bar/', '/foo/xxx/'。它们恰好就是目录'/foo/'下的所有子目
      #  录。用delimiter获取公共前缀的方法避免了查询当前bucket下的所有
      #   object（可能数量巨大），是用于模拟目录结构的常用做法。
      # @return [Enumerator<Object>] 其中Object可能是{OSS::Object}，也
      #  可能是{String}，此时它是一个公共前缀
      # @example
      #  all = bucket.list_objects
      #  all.each do |i|
      #    if i.is_a?(Object)
      #      puts "Object: #{i.key}"
      #    else
      #      puts "Common prefix: #{i}"
      #    end
      #  end
      def list_objects(opts = {})
        Iterator::Objects.new(
          @protocol, name, opts.merge(encoding: KeyEncoding::URL)).to_enum
      end

      # 向Bucket中上传一个object
      # @param key [String] Object的名字
      # @param opts [Hash] 上传object时的选项（可选）
      # @option opts [String] :file 设置所上传的文件
      # @option opts [String] :content_type 设置所上传的内容的
      #  Content-Type，默认是application/octet-stream
      # @option opts [Hash] :metas 设置object的meta，这是一些用户自定
      #  义的属性，它们会和object一起存储，在{#get_object}的时候会
      #  返回这些meta。属性的key不区分大小写。例如：{ 'year' => '2015' }
      # @option opts [Callback] :callback 指定操作成功后OSS的
      #  上传回调，上传成功后OSS会向用户的应用服务器发一个HTTP POST请
      #  求，`:callback`参数指定这个请求的相关参数
      # @option opts [Hash] :headers 指定请求的HTTP Header，不区分大小
      #  写。这里指定的值会覆盖通过`:content_type`和`:metas`设置的值。
      # @yield [HTTP::StreamWriter] 如果调用的时候传递了block，则写入
      #  到object的数据由block指定
      # @example 流式上传数据
      #   put_object('x'){ |stream| 100.times { |i| stream << i.to_s } }
      #   put_object('x'){ |stream| stream << get_data }
      # @example 上传文件
      #   put_object('x', :file => '/tmp/x')
      # @example 指定Content-Type和metas
      #   put_object('x', :file => '/tmp/x', :content_type => 'text/html',
      #              :metas => {'year' => '2015', 'people' => 'mary'})
      # @example 指定Callback
      #   callback = Aliyun::OSS::Callback.new(
      #     url: 'http://10.101.168.94:1234/callback',
      #     query: {user: 'put_object'},
      #     body: 'bucket=${bucket}&object=${object}'
      #   )
      #
      #   bucket.put_object('files/hello', callback: callback)
      # @raise [CallbackError] 如果文件上传成功而Callback调用失败，抛
      #  出此错误
      # @note 如果opts中指定了`:file`，则block会被忽略
      # @note 如果指定了`:callback`，则可能文件上传成功，但是callback
      #  执行失败，此时会抛出{OSS::CallbackError}，用户可以选择接住这
      #  个异常，以忽略Callback调用错误
      def put_object(key, opts = {}, &block)
        args = opts.dup

        file = args[:file]
        args[:content_type] ||= get_content_type(file) if file
        args[:content_type] ||= get_content_type(key)

        if file
          @protocol.put_object(name, key, args) do |sw|
            File.open(File.expand_path(file), 'rb') do |f|
              sw << f.read(Protocol::STREAM_CHUNK_SIZE) until f.eof?
            end
          end
        else
          @protocol.put_object(name, key, args, &block)
        end
      end

      # 从Bucket中下载一个object
      # @param key [String] Object的名字
      # @param opts [Hash] 下载Object的选项（可选）
      # @option opts [Array<Integer>] :range 指定下载object的部分数据，
      #  range应只包含两个数字，表示一个*左开右闭*的bytes range
      # @option opts [String] :file 指定将下载的object写入到文件中
      # @option opts [Hash] :condition 指定下载object需要满足的条件
      #   * :if_modified_since (Time) 指定如果object的修改时间晚于这个值，则下载
      #   * :if_unmodified_since (Time) 指定如果object从这个时间后再无修改，则下载
      #   * :if_match_etag (String) 指定如果object的etag等于这个值，则下载
      #   * :if_unmatch_etag (String) 指定如果object的etag不等于这个值，则下载
      # @option opts [Hash] :headers 指定请求的HTTP Header，不区分大小
      #  写。这里指定的值会覆盖通过`:range`和`:condition`设置的值。
      # @option opts [Hash] :rewrite 指定下载object时Server端返回的响应头部字段的值
      #   * :content_type (String) 指定返回的响应中Content-Type的值
      #   * :content_language (String) 指定返回的响应中Content-Language的值
      #   * :expires (Time) 指定返回的响应中Expires的值
      #   * :cache_control (String) 指定返回的响应中Cache-Control的值
      #   * :content_disposition (String) 指定返回的响应中Content-Disposition的值
      #   * :content_encoding (String) 指定返回的响应中Content-Encoding的值
      # @return [OSS::Object] 返回Object对象
      # @yield [String] 如果调用的时候传递了block，则获取到的object的数据交由block处理
      # @example 流式下载文件
      #   get_object('x'){ |chunk| handle_chunk_data(chunk) }
      # @example 下载到本地文件
      #   get_object('x', :file => '/tmp/x')
      # @example 指定检查条件
      #   get_object('x', :file => '/tmp/x', :condition => {:if_match_etag => 'etag'})
      # @example 指定重写响应的header信息
      #   get_object('x', :file => '/tmp/x', :rewrite => {:content_type => 'text/html'})
      # @note 如果opts中指定了`:file`，则block会被忽略
      # @note 如果既没有指定`:file`也没有指定block，则只获取Object
      #  meta而不下载Object内容
      def get_object(key, opts = {}, &block)
        obj = nil
        file = opts[:file]
        if file
          File.open(File.expand_path(file), 'wb') do |f|
            obj = @protocol.get_object(name, key, opts) do |chunk|
              f.write(chunk)
            end
          end
        elsif block
          obj = @protocol.get_object(name, key, opts, &block)
        else
          obj = @protocol.get_object_meta(name, key, opts)
        end

        obj
      end

      # 更新Object的metas
      # @param key [String] Object的名字
      # @param metas [Hash] Object的meta
      # @param conditions [Hash] 指定更新Object meta需要满足的条件，
      #  同{#get_object}
      # @return [Hash] 更新后文件的信息
      #  * :etag [String] 更新后文件的ETag
      #  * :last_modified [Time] 更新后文件的最后修改时间
      def update_object_metas(key, metas, conditions = {})
        @protocol.copy_object(
          name, key, key,
          :meta_directive => MetaDirective::REPLACE,
          :metas => metas,
          :condition => conditions)
      end

      # 判断一个object是否存在
      # @param key [String] Object的名字
      # @return [Boolean] 如果Object存在返回true，否则返回false
      def object_exists?(key)
        begin
          get_object(key)
          return true
        rescue ServerError => e
          return false if e.http_code == 404
          raise e
        end

        false
      end

      alias :object_exist? :object_exists?

      # 向Bucket中的object追加内容。如果object不存在，则创建一个
      # Appendable Object。
      # @param key [String] Object的名字
      # @param opts [Hash] 上传object时的选项（可选）
      # @option opts [String] :file 指定追加的内容从文件中读取
      # @option opts [String] :content_type 设置所上传的内容的
      #  Content-Type，默认是application/octet-stream
      # @option opts [Hash] :metas 设置object的meta，这是一些用户自定
      #  义的属性，它们会和object一起存储，在{#get_object}的时候会
      #  返回这些meta。属性的key不区分大小写。例如：{ 'year' => '2015' }
      # @option opts [Hash] :headers 指定请求的HTTP Header，不区分大小
      #  写。这里指定的值会覆盖通过`:content_type`和`:metas`设置的值。
      # @example 流式上传数据
      #   pos = append_object('x', 0){ |stream| 100.times { |i| stream << i.to_s } }
      #   append_object('x', pos){ |stream| stream << get_data }
      # @example 上传文件
      #   append_object('x', 0, :file => '/tmp/x')
      # @example 指定Content-Type和metas
      #   append_object('x', 0, :file => '/tmp/x', :content_type => 'text/html',
      #                 :metas => {'year' => '2015', 'people' => 'mary'})
      # @return [Integer] 返回下次append的位置
      # @yield [HTTP::StreamWriter] 同 {#put_object}
      def append_object(key, pos, opts = {}, &block)
        args = opts.dup

        file = args[:file]
        args[:content_type] ||= get_content_type(file) if file
        args[:content_type] ||= get_content_type(key)

        if file
          next_pos = @protocol.append_object(name, key, pos, args) do |sw|
            File.open(File.expand_path(file), 'rb') do |f|
              sw << f.read(Protocol::STREAM_CHUNK_SIZE) until f.eof?
            end
          end
        else
          next_pos = @protocol.append_object(name, key, pos, args, &block)
        end

        next_pos
      end

      # 将Bucket中的一个object拷贝成另外一个object
      # @param source [String] 源object名字
      # @param dest [String] 目标object名字
      # @param opts [Hash] 拷贝object时的选项（可选）
      # @option opts [String] :src_bucket 源object所属的Bucket，默认与
      #  目标文件为同一个Bucket。源Bucket与目标Bucket必须属于同一个Region。
      # @option opts [String] :acl 目标文件的acl属性，默认为private
      # @option opts [String] :meta_directive 指定是否拷贝源object的
      #  meta信息，默认为{OSS::MetaDirective::COPY}：即拷贝object的时
      #  候也拷贝meta信息。
      # @option opts [Hash] :metas 设置object的meta，这是一些用户自定
      #  义的属性，它们会和object一起存储，在{#get_object}的时候会
      #  返回这些meta。属性的key不区分大小写。例如：{ 'year' => '2015'
      #  }。如果:meta_directive为{OSS::MetaDirective::COPY}，则:metas
      #  会被忽略。
      # @option opts [Hash] :condition 指定拷贝object需要满足的条件，
      #  同 {#get_object}
      # @return [Hash] 目标文件的信息
      #  * :etag [String] 目标文件的ETag
      #  * :last_modified [Time] 目标文件的最后修改时间
      def copy_object(source, dest, opts = {})
        args = opts.dup

        args[:content_type] ||= get_content_type(dest)
        @protocol.copy_object(name, source, dest, args)
      end

      # 删除一个object
      # @param key [String] Object的名字
      def delete_object(key)
        @protocol.delete_object(name, key)
      end

      # 批量删除object
      # @param keys [Array<String>] Object的名字集合
      # @param opts [Hash] 删除object的选项（可选）
      # @option opts [Boolean] :quiet 指定是否允许Server返回成功删除的
      #  object，默认为false，即返回删除结果
      # @return [Array<String>] 成功删除的object的名字，如果指定
      #  了:quiet参数，则返回[]
      def batch_delete_objects(keys, opts = {})
        @protocol.batch_delete_objects(
          name, keys, opts.merge(encoding: KeyEncoding::URL))
      end

      # 设置object的ACL
      # @param key [String] Object的名字
      # @param acl [String] Object的{OSS::ACL ACL}
      def set_object_acl(key, acl)
        @protocol.put_object_acl(name, key, acl)
      end

      # 获取object的ACL
      # @param key [String] Object的名字
      # @return [String] object的{OSS::ACL ACL}
      def get_object_acl(key)
        @protocol.get_object_acl(name, key)
      end

      # 获取object的CORS规则
      # @param key [String] Object的名字
      # @return [OSS::CORSRule]
      def get_object_cors(key)
        @protocol.get_object_cors(name, key)
      end

      ##
      # 断点续传相关的API
      #

      # 上传一个本地文件到bucket中的一个object，支持断点续传。指定的文
      # 件会被分成多个分片进行上传，只有所有分片都上传成功整个文件才
      # 上传成功。
      # @param key [String] Object的名字
      # @param file [String] 本地文件的路径
      # @param opts [Hash] 上传文件的可选项
      # @option opts [String] :content_type 设置所上传的内容的
      #  Content-Type，默认是application/octet-stream
      # @option opts [Hash] :metas 设置object的meta，这是一些用户自定
      #  义的属性，它们会和object一起存储，在{#get_object}的时候会
      #  返回这些meta。属性的key不区分大小写。例如：{ 'year' => '2015' }
      # @option opts [Integer] :part_size 设置分片上传时每个分片的大小，
      #  默认为10 MB。断点上传最多允许10000个分片，如果文件大于10000个
      #  分片的大小，则每个分片的大小会大于10MB。
      # @option opts [String] :cpt_file 断点续传的checkpoint文件，如果
      #  指定的cpt文件不存在，则会在file所在目录创建一个默认的cpt文件，
      #  命名方式为：file.cpt，其中file是用户要上传的文件。在上传的过
      #  程中会不断更新此文件，成功完成上传后会删除此文件；如果指定的
      #  cpt文件已存在，则从cpt文件中记录的点继续上传。
      # @option opts [Boolean] :disable_cpt 是否禁用checkpoint功能，如
      #  果设置为true，则在上传的过程中不会写checkpoint文件，这意味着
      #  上传失败后不能断点续传，而只能重新上传整个文件。如果这个值为
      #  true，则:cpt_file会被忽略。
      # @option opts [Callback] :callback 指定文件上传成功后OSS的
      #  上传回调，上传成功后OSS会向用户的应用服务器发一个HTTP POST请
      #  求，`:callback`参数指定这个请求的相关参数
      # @option opts [Hash] :headers 指定请求的HTTP Header，不区分大小
      #  写。这里指定的值会覆盖通过`:content_type`和`:metas`设置的值。
      # @yield [Float] 如果调用的时候传递了block，则会将上传进度交由
      #  block处理，进度值是一个0-1之间的小数
      # @raise [CheckpointBrokenError] 如果cpt文件被损坏，则抛出此错误
      # @raise [FileInconsistentError] 如果指定的文件与cpt中记录的不一
      #  致，则抛出此错误
      # @raise [CallbackError] 如果文件上传成功而Callback调用失败，抛
      #  出此错误
      # @example
      #   bucket.resumable_upload('my-object', '/tmp/x') do |p|
      #     puts "Progress: #{(p * 100).round(2)} %"
      #   end
      # @example 指定Callback
      #   callback = Aliyun::OSS::Callback.new(
      #     url: 'http://10.101.168.94:1234/callback',
      #     query: {user: 'put_object'},
      #     body: 'bucket=${bucket}&object=${object}'
      #   )
      #
      #   bucket.resumable_upload('files/hello', '/tmp/x', callback: callback)
      # @note 如果指定了`:callback`，则可能文件上传成功，但是callback
      #  执行失败，此时会抛出{OSS::CallbackError}，用户可以选择接住这
      #  个异常，以忽略Callback调用错误
      def resumable_upload(key, file, opts = {}, &block)
        args = opts.dup

        args[:content_type] ||= get_content_type(file)
        args[:content_type] ||= get_content_type(key)
        cpt_file = args[:cpt_file] || get_cpt_file(file)

        Multipart::Upload.new(
          @protocol, options: args,
          progress: block,
          object: key, bucket: name, creation_time: Time.now,
          file: File.expand_path(file), cpt_file: cpt_file
        ).run
      end

      # 下载bucket中的一个object到本地文件，支持断点续传。指定的object
      # 会被分成多个分片进行下载，只有所有的分片都下载成功整个object才
      # 下载成功。对于每个下载的分片，会在file所在目录建立一个临时文件
      # file.part.N，下载成功后这些part文件会被合并成最后的file然后删
      # 除。
      # @param key [String] Object的名字
      # @param file [String] 本地文件的路径
      # @param opts [Hash] 下载文件的可选项
      # @option opts [Integer] :part_size 设置分片上传时每个分片的大小，
      #  默认为10 MB。断点下载最多允许100个分片，如果文件大于100个分片，
      #  则每个分片的大小会大于10 MB
      # @option opts [String] :cpt_file 断点续传的checkpoint文件，如果
      #  指定的cpt文件不存在，则会在file所在目录创建一个默认的cpt文件，
      #  命名方式为：file.cpt，其中file是用户要下载的文件名。在下载的过
      #  程中会不断更新此文件，成功完成下载后会删除此文件；如果指定的
      #  cpt文件已存在，则从cpt文件中记录的点继续下载。
      # @option opts [Boolean] :disable_cpt 是否禁用checkpoint功能，如
      #  果设置为true，则在下载的过程中不会写checkpoint文件，这意味着
      #  下载失败后不能断点续传，而只能重新下载整个文件。如果这个值为true，
      #  则:cpt_file会被忽略。
      # @option opts [Hash] :condition 指定下载object需要满足的条件，
      #  同 {#get_object}
      # @option opts [Hash] :headers 指定请求的HTTP Header，不区分大小
      #  写。这里指定的值会覆盖通过`:condition`设置的值。
      # @option opts [Hash] :rewrite 指定下载object时Server端返回的响
      #  应头部字段的值，同 {#get_object}
      # @yield [Float] 如果调用的时候传递了block，则会将下载进度交由
      #  block处理，进度值是一个0-1之间的小数
      # @raise [CheckpointBrokenError] 如果cpt文件被损坏，则抛出此错误
      # @raise [ObjectInconsistentError] 如果指定的object的etag与cpt文
      #  件中记录的不一致，则抛出错误
      # @raise [PartMissingError] 如果已下载的部分(.part文件)找不到，
      #  则抛出此错误
      # @raise [PartInconsistentError] 如果已下载的部分(.part文件)的
      #  MD5值与cpt文件记录的不一致，则抛出此错误
      # @note 已经下载的部分会在file所在的目录创建.part文件，命名方式
      #  为file.part.N
      # @example
      #   bucket.resumable_download('my-object', '/tmp/x') do |p|
      #     puts "Progress: #{(p * 100).round(2)} %"
      #   end
      def resumable_download(key, file, opts = {}, &block)
        args = opts.dup

        args[:content_type] ||= get_content_type(file)
        args[:content_type] ||= get_content_type(key)
        cpt_file = args[:cpt_file] || get_cpt_file(file)

        Multipart::Download.new(
          @protocol, options: args,
          progress: block,
          object: key, bucket: name, creation_time: Time.now,
          file: File.expand_path(file), cpt_file: cpt_file
        ).run
      end

      # 列出此Bucket中正在进行的multipart上传请求，不包括已经完成或者
      # 被取消的。
      # @param [Hash] opts 可选项
      # @option opts [String] :key_marker object key的标记，根据有没有
      #  设置:id_marker，:key_marker的含义不同：
      #  1. 如果未设置:id_marker，则只返回object key在:key_marker之后
      #     （字典序，不包含marker）的upload请求
      #  2. 如果设置了:id_marker，则返回object key在:key_marker之后
      #     （字典序，不包含marker）的uplaod请求*和*Object
      #     key与:key_marker相等，*且*upload id在:id_marker之后（字母
      #     表顺序排序，不包含marker）的upload请求
      # @option opts [String] :id_marker upload id的标记，如
      #  果:key_marker没有设置，则此参数会被忽略；否则与:key_marker一起
      #  决定返回的结果（见上）
      # @option opts [String] :prefix 如果指定，则只返回object key中符
      #  合指定前缀的upload请求
      # @return [Enumerator<Multipart::Transaction>] 其中每一个元素表
      #  示一个upload请求
      # @example
      #   key_marker = 1, id_marker = null
      #   # return <2, 0>, <2, 1>, <3, 0> ...
      #   key_marker = 1, id_marker = 5
      #   # return <1, 6>, <1, 7>, <2, 0>, <3, 0> ...
      def list_uploads(opts = {})
        Iterator::Uploads.new(
          @protocol, name, opts.merge(encoding: KeyEncoding::URL)).to_enum
      end

      # 取消一个multipart上传请求，一般用于清除Bucket下因断点上传而产
      # 生的文件碎片。成功取消后属于这个上传请求的分片都会被清除。
      # @param [String] upload_id 上传请求的id，可通过{#list_uploads}
      #  获得
      # @param [String] key Object的名字
      def abort_upload(upload_id, key)
        @protocol.abort_multipart_upload(name, key, upload_id)
      end

      # 获取Bucket的URL
      # @return [String] Bucket的URL
      def bucket_url
        @protocol.get_request_url(name)
      end

      # 获取Object的URL
      # @param [String] key Object的key
      # @param [Boolean] sign 是否对URL进行签名，默认为是
      # @param [Integer] expiry URL的有效时间，单位为秒，默认为60s
      # @param [Hash] parameters 附加的query参数，默认为空
      # @return [String] 用于直接访问Object的URL
      def object_url(key, sign = true, expiry = 60, parameters = {})
        url = @protocol.get_request_url(name, key).gsub('%2F', '/')
        query = parameters.dup

        if sign
          #header
          expires = Time.now.to_i + expiry
          headers = {
            'date' => expires.to_s,
          }

          #query 
          if @protocol.get_sts_token
            query['security-token'] = @protocol.get_sts_token
          end

          res = {
            :path => @protocol.get_resource_path(name, key),
            :sub_res => query,
          }
          signature = Util.get_signature(@protocol.get_access_key_secret, 'GET', headers, res)

          query['Expires'] = expires.to_s
          query['OSSAccessKeyId'] = @protocol.get_access_key_id
          query['Signature'] = signature
        end  

        query_string = query.map { |k, v| v ? [k, CGI.escape(v)].join("=") : k }.join("&")
        link_char = query_string.empty? ? '' : '?'
        [url, query_string].join(link_char)
      end

      # 获取用户所设置的ACCESS_KEY_ID
      # @return [String] 用户的ACCESS_KEY_ID
      def access_key_id
        @protocol.get_access_key_id
      end

      # 用ACCESS_KEY_SECRET对内容进行签名
      # @param [String] string_to_sign 要进行签名的内容
      # @return [String] 生成的签名
      def sign(string_to_sign)
        @protocol.sign(string_to_sign)
      end

      # Get the download crc status
      # @return true(download crc enable) or false(download crc disable)
      def download_crc_enable
        @protocol.download_crc_enable
      end

      # Get the upload crc status
      # @return true(upload crc enable) or false(upload crc disable)
      def upload_crc_enable
        @protocol.upload_crc_enable
      end

      private
      # Infer the file's content type using MIME::Types
      # @param file [String] the file path
      # @return [String] the infered content type or nil if it fails
      #  to infer the content type
      def get_content_type(file)
        t = MIME::Types.of(file)
        t.first.content_type unless t.empty?
      end

      # Get the checkpoint file path for file
      # @param file [String] the file path
      # @return [String] the checkpoint file path
      def get_cpt_file(file)
        "#{File.expand_path(file)}.cpt"
      end
    end # Bucket
  end # OSS
end # Aliyun
