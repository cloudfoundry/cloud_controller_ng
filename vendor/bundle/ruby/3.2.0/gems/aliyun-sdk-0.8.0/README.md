# Alibaba Cloud OSS SDK for Ruby

[![Gem Version](https://badge.fury.io/rb/aliyun-sdk.svg)](https://badge.fury.io/rb/aliyun-sdk)
[![Build Status](https://travis-ci.org/aliyun/aliyun-oss-ruby-sdk.svg?branch=master)](https://travis-ci.org/aliyun/aliyun-oss-ruby-sdk?branch=master)
[![Coverage Status](https://coveralls.io/repos/aliyun/aliyun-oss-ruby-sdk/badge.svg?branch=master&service=github)](https://coveralls.io/github/aliyun/aliyun-oss-ruby-sdk?branch=master)

## [README of Chinese](https://github.com/aliyun/aliyun-oss-ruby-sdk/blob/master/README-CN.md)

## About

Alibaba Cloud OSS SDK for Ruby is a Ruby client program for convenient access to Alibaba Cloud OSS (Object Storage Service)
RESTful APIs. For more information about OSS, visit [the OSS official website]( http://www.aliyun.com/product/oss).

## Run environment

- Ruby ***2.0*** or above. For Ruby 1.9, please use v0.5.0.
- *Windows*, *Linux* or *OS X* system that supports Ruby. 

To learn how to install Ruby, refer to: [ruby-lang](https://www.ruby-lang.org/en/documentation/installation/). 

## Quick start

### Activate an OSS account

Log onto [the official website](http://www.aliyun.com/product/oss) and click *Activate Now*. Follow the prompts 
to activate OSS. After the service is activated, go to *Console* to view your `AccessKeyId` and 
`AccessKeySecret`. These two information items are required when you use Alibaba Cloud OSS SDK. 

### Install Alibaba Cloud OSS SDK for Ruby

    gem install aliyun-sdk

Include the following in your project or 'irb' command: 

    require 'aliyun/oss'

**Note:**

- Some gems on which the SDK depends are local extensions, and you need to install ruby-dev to compile locally
   extended gems after you install Ruby. 
- The environment for running the SDK-dependent gem (nokogiri) for processing XML must have the zlib library.

The following method is used to install the preceding dependencies taking *Ubuntu* as an example:

    sudo apt-get install ruby-dev
    sudo apt-get install zlib1g-dev

The practices for other systems are similar. 

### Create a client

    client = Aliyun::OSS::Client.new(
      :endpoint => 'endpoint',
      :access_key_id => 'access_key_id',
      :access_key_secret => 'access_key_secret')

In specific, the `endpoint` is the OSS service address. The address may vary based on different regions for the node. For example, 
the address for a Hangzhou node is: `http://oss-cn-hangzhou.aliyuncs.com`. For addresses for other nodes, see:  [Node List][region-list]. 

The `access_key_id` and `access_key_secret` are credentials for your service. You can view them in `Console` on the official website. **Please keep your AccessKeySecret safe. Disclosing the AccessKeySecret may compromise your data security**. 

#### Use a bound domain as the endpoint

OSS supports binding a custom domain name and allows you to direct your domain name to the OSS service address 
(CNAME) of Alibaba Cloud. In this way, you don't need to change the resource path in your app when migrating your data to the OSS. The bound domain name 
points to a bucket in the OSS. The domain name binding operation can only be carried out in the OSS console. For more information about 
binding a custom domain name, visit the official website: [Binding Custom Domain Names in OSS][custom-domain]. 

After you have bound a custom domain name, you can use the standard OSS service address as the specified endpoint of the OSS, 
or use the bound domain name: 

    client = Aliyun::OSS::Client.new(
      :endpoint => 'http://img.my-domain.com',
      :access_key_id => 'access_key_id',
      :access_key_secret => 'access_key_secret',
      :cname => true)

**Note:**

- You must set the `cname` to ***true*** when initializing the client. 
- The custom domain name is bound to a bucket of the OSS, so the client created in this method does not support 
   List_buckets operations. 
- You still need to specify the bucket name during the {Aliyun::OSS::Client#get_bucket} operation and the bucket name should be the same as that 
   bound to the domain name. 

#### Create a client using STS

OSS supports access via STS. For more information about STS, refer to [Alibaba Cloud STS][aliyun-sts]. 
Before using STS, you must apply for a temporary token from the STS. 
Alibaba Cloud Ruby SDK contains the STS SDK, and you only need to `require 'aliyun/sts'` for usage: 

    require 'aliyun/sts'
    sts = Aliyun::STS::Client.new(
      access_key_id: 'access_key_id',
      access_key_secret: 'access_key_secret')

    token = sts.assume_role('role-arn', 'my-app')

    client = Aliyun::OSS::Client.new(
      :endpoint => 'http://oss-cn-hangzhou.aliyuncs.com',
      :access_key_id => token.access_key_id,
      :access_key_secret => token.access_key_secret,
      :sts_token => token.security_token)

**Note:** the `:sts_token` parameter must be specified for using STS. You can also apply for a token with a policy through `STS::Client`, for details, refer to [API Documentation][sdk-api]. 

### List all the current buckets

    buckets = client.list_buckets
    buckets.each{ |b| puts b.name }

The `list_buckets` command returns an iterator for you to get the information of each bucket in order. Bucket
For the object structure, see {Aliyun::OSS::Bucket} in the API documentation. 

### Create a bucket

    bucket = client.create_bucket('my-bucket')

### List all the objects in a bucket

    bucket = client.get_bucket('my-bucket')
    objects = bucket.list_objects
    objects.each{ |o| puts o.key }

The `list_objects` command returns an iterator for you to get the information of each object in order. Object
For the object structure, see {Aliyun::OSS::Object} in the API documentation.

### Create an object in the bucket

    bucket.put_object(object_key){ |stream| stream << 'hello world' }

You can also create an object by uploading a local file: 

    bucket.put_object(object_key, :file => local_file)

### Download an object from the bucket

    bucket.get_object(object_key){ |content| puts content }

You can also download the object to a local file: 

    bucket.get_object(object_key, :file => local_file)

### Copy an object

    bucket.copy_object(from_key, to_key)

### Identify whether an object exists

    bucket.object_exists?(object_key)

For more operations on buckets, refer to {Aliyun::OSS::Bucket} in the API documentation.

## Simulate the directory structure

OSS is a storage service for objects and does not support the directory structure. All objects are flatly structured. But 
you can simulate the directory structure by setting the object key in the format "foo/bar/file". 
Suppose there are several objects as follows: 

    foo/x
    foo/bar/f1
    foo/bar/dir/file
    foo/hello/file

Listing all the objects under the "foo/" directory means to perform the *list_objects* operation with "foo/" as the prefix. 
But this method will also list all the objects under "foo/bar/". That's why we need the delimiter parameter. 
This parameter means to stop processing at the first delimiter after the prefix. The key during the process acts as 
the common prefix of objects, objects with the prefix will be included in the *list_objects* result. 

    objs = bucket.list_objects(:prefix => 'foo/', :delimiter => '/')
    objs.each do |i|
      if i.is_a?(Aliyun::OSS::Object) # a object
        puts "object: #{i.key}"
      else
        puts "common prefix: #{i}"
      end
    end
    # output
    object: foo/x
    common prefix: foo/bar/
    common prefix: foo/hello/

Common prefixes free you from traversing all the objects (the number of objects may be huge) to determine the prefix, 
and is quite helpful for simulating the directory structure. 

## Upload callback

You can specify a *callback* for `put_object` and `resumable_upload` so that after the file 
is successfully uploaded to the OSS, the OSS will initiate an *HTTP POST* request to the server address you provided 
to notify you that the corresponding event has occurred. You can perform desired actions after receiving the notification, 
such as updating the database and making statistics. For more details about upload callback, refer to [OSS Upload Callback][oss-callback]. 

The example below demonstrates how to use the upload callback: 

    callback = Aliyun::OSS::Callback.new(
      url: 'http://10.101.168.94:1234/callback',
      query: {user: 'put_object'},
      body: 'bucket=${bucket}&object=${object}'
    )

    begin
      bucket.put_object('files/hello', callback: callback)
    rescue Aliyun::OSS::CallbackError => e
      puts "Callback failed: #{e.message}"
    end

**Note:**

- The callback URL **must not** contain the query string which must be specified in the `:query` parameter.
- In the event that the file is successfully uploaded but callback execution fails, the client will throw
   `CallbackError`. To ignore the error, you need to explicitly catch the exception.
- For detailed examples, refer to [callback.rb](examples/aliyun/oss/callback.rb).
- For servers that support callback, refer to [callback_server.rb](rails/aliyun_oss_callback_server.rb).

## Resumable upload/download

OSS supports the storage of large objects. If the upload/download task of a large object is interrupted (due to network transient disconnections, program crashes, or machine power-off), 
the re-upload/re-download is taxing on system resources. The OSS supports 
multipart upload/download to divide a large object into multiple parts for upload/download. Alibaba Cloud OSS SDK
provides the resumable upload/download feature based on this principle. If an interruption occurs, you can resume the upload/download task 
beginning with the interrupted part. ***Resumable upload/download is recommended for objects 
larger than 100MB***. 

### Resumable upload

    bucket.resumable_upload(object_key, local_file, :cpt_file => cpt_file)

In specific, `:cpt_file` specifies the location of the checkpoint object which stores the intermediate state of the upload. 
If no object is specified, the SDK will generate a 
`local_file.cpt` in the directory of the `local_file`. After the upload interruption, you only need to provide the same cpt object for the upload task to resume from 
the interrupted part. The typical upload code is: 

    retry_times = 5
    retry_times.times do
      begin
        bucket.resumable_upload(object_key, local_file)
      rescue => e
        logger.error(e.message)
      end
    end

**Notes:**

- The SDK records the upload intermediate states in the cpt object. Therefore, ensure that you have
   write permission on the cpt object.
- The cpt object records the intermediate state information of the upload and has a self-checking function. You cannot edit the object.
Upload will fail if the cpt object is corrupted. When the upload is completed, the checkpoint file will be deleted.

### Resumable download

    bucket.resumable_download(object_key, local_file, :cpt_file => cpt_file)

In specific, `:cpt_file` specifies the location of the checkpoint object which stores the intermediate state of the download.
If no object is specified, the SDK will generate a
`local_file.cpt` in the directory of the `local_file`. After the download interruption, you only need to provide the same cpt object for the download task to resume from
the interrupted part. The typical download code is:

    retry_times = 5
    retry_times.times do
      begin
        bucket.resumable_download(object_key, local_file)
      rescue => e
        logger.error(e.message)
      end
    end

**Notes:**

- During the download process, a temporary object of `local_file.part.N` will be generated in the directory of the `local_file` 
   for each part downloaded. When the download is completed, the objects will be deleted.
   You cannot edit or delete the part objects, otherwise the download will not proceed. 
- The SDK records the download intermediate states in the cpt object; therefore, ensure that you have
   write permission on the cpt object.
- The cpt object records the intermediate state information of the download and has a self-checking function. You cannot edit the object.
   Download will fail if the cpt object is corrupted. When the download is completed, the `checkpoint` object will be deleted.


# Appendable object

Objects in Alibaba Cloud OSS can be divided into two types: Normal and Appendable. 

- A normal object functions as a whole for every upload. If an object already exists, 
  the later uploaded object will overwrite the previous object with the same key. 
- An appendable object is created through `append_object` for the first time. The later uploaded 
  object through `append_object` will not overwrite the previous one, but will append content to the end of the object. 
- You cannot append content to a normal object. 
- You cannot copy an appendable object. 

### Create an appendable object

    bucket.append_object(object_key, 0){ |stream| stream << "hello world" }

The second parameter indicates the position to append the content. This parameter is ***0*** for the first append to the object. In later 
append operations, the value of this parameter is the length of the object before the append. 

Of course, you can also read the appended content from the object: 

    bucket.append_object(object_key, 0, :file => local_file)

### Append content to the object

    pos = bucket.get_object(object_key).size
    next_pos = bucket.append_object(object_key, pos, :file => local_file)

During the first append, you can use {Aliyun::OSS::Bucket#get_object} to get the object length. 
For later append operations, you can refer to the response of {Aliyun::OSS::Bucket#append_object} to determine the length value for next append. 

***Note:*** Concurrent `append_object` and `next_pos` operations do not always produce correct results. 

## Object meta information

Besides the object content, the OSS also allows you to set some *meta information* for the object during object uploading. 
The meta information is a key-value pair to identify the specific attributes of the object. The 
meta information will be stored together with the object and returned to users in `get_object` and `get_object_meta` 
operations. 

    bucket.put_object(object_key, :file => local_file,
                      :metas => {
                        'key1' => 'value1',
                        'key2' => 'value2'})

    obj = bucket.get_object(object_key, :file => localfile)
    puts obj.metas

**Note:**

- The key and value of the meta information can only be simple ASCII non-newline characters and the total size must not exceed ***8KB***. 
- In the copy object operation, the meta information of the source object will be copied by default. If you don't want this, explicitly set the 
   `:meta_directive` to {Aliyun::OSS::MetaDirective::REPLACE}.

## Permission control

OSS allows you to set access permissions for buckets and objects respectively, so that you can conveniently control
external access to your resources. A bucket is enabled with three types of access permissions:

- public-read-write: Anonymous users are allowed to create/retrieve/delete objects in the bucket. 
- public-read: Anonymous users are allowed to retrieve objects in the bucket. 
- private: Anonymous users are not allowed to access the bucket. Signature is required for all accesses. 

When a bucket is created, the private permission applies by default. You can use 'bucket.acl=' to set
the ACL of the bucket.

    bucket.acl = Aliyun::OSS::ACL::PUBLIC_READ
    puts bucket.acl # public-read

An object is enabled with four types of access permissions:

- default: The object inherits the access permissions of the bucket it belongs to, that is, the access permission of the object is the same as that of the bucket where the object is stored. 
- public-read-write: Anonymous users are allowed to read/write the object. 
- public-read: Anonymous users are allowed to read the object. 
- private: Anonymous users are not allowed to access the object. Signature is required for all accesses.

When an object is created, the default permission applies by default. You can use
'bucket.set_object_acl' to configure the ACL of the object.

    acl = bucket.get_object_acl(object_key)
    puts acl # default
    bucket.set_object_acl(object_key, Aliyun::OSS::ACL::PUBLIC_READ)
    acl = bucket.get_object_acl(object_key)
    puts acl # public-read

**Notes:**

- If an object is configured with an ACL policy, the object ACL takes priority during permission authentication
   when the object is accessed. The bucket ACL will be ignored.
- If anonymous access is allowed (public-read or public-read-write is configured for the object), you
   can directly access the object using a browser. For example, 

        http://bucket-name.oss-cn-hangzhou.aliyuncs.com/object.jpg

- A bucket or an object with the public permission can be accessed by an anonymous client which is created with the following code:

        # If access_key_id and access_key_secret are not specified, an anonymous client will be created. The client can only access 
        # the buckets and objects with the public permission.
        client = Client.new(:endpoint => 'oss-cn-hangzhou.aliyuncs.com')
        bucket = client.get_bucket('public-bucket')
        obj = bucket.get_object('public-object', :file => local_file)

## Run examples

Some example projects are provided in the examples/ directory of the SDK to demonstrate the SDK features. You can run the examples 
after some configuration. The permission information and the bucket information required by the examples are available in the 
`~/.oss.yml` configuration file under the *HOME* directory. The information should include the following fields (**Note the space after the colon**):

    endpoint: oss-cn-hangzhou.aliyuncs.com
    cname: false
    access_key_id: <ACCESS KEY ID>
    access_key_secret: <ACCESS KEY SECRET>
    bucket: <BUCKET NAME>

You need to create (if not in existence) or modify the content and run the example project: 

    ruby examples/aliyun/oss/bucket.rb

## Run test

```bash
bundle exec rake spec

export RUBY_SDK_OSS_ENDPOINT=endpoint
export RUBY_SDK_OSS_ID=AccessKeyId
export RUBY_SDK_OSS_KEY=AccessKeySecret
export RUBY_SDK_OSS_BUCKET=bucket-name

bundle exec rake test
```

## License

- MIT

## More

For more documentation, see:

- Alibaba Cloud OSS Ruby SDK [documentation](https://help.aliyun.com/document_detail/oss/sdk/ruby-sdk/install.html).
- Alibaba Cloud OSS [documentation](http://help.aliyun.com/product/8314910_oss.html).


[region-list]: https://help.aliyun.com/document_detail/oss/user_guide/endpoint_region.html
[custom-domain]: https://help.aliyun.com/document_detail/oss/user_guide/oss_concept/oss_cname.html
[aliyun-sts]: https://help.aliyun.com/document_detail/ram/intro/concepts.html
[sdk-api]: http://www.rubydoc.info/gems/aliyun-sdk/
[oss-callback]: https://help.aliyun.com/document_detail/oss/user_guide/upload_object/upload_callback.html

