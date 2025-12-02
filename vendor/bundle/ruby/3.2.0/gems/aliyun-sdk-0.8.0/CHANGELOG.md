## Change Log

### v0.8.0 / 2020-08-17

- add bucket encryption
- add bucket versioning
- add env parameter to set default log level

### v0.7.3 / 2020-06-28

- add variable control log output path


### v0.7.2 / 2020-06-05

- add env parameter to descide whether output log file

### v0.7.1 / 2019-11-16

- add the validity check of bucket name
- add parameters argument for buclet.object_url api
- fix http.get_request_url function bug
- fix warning constant ::Fixnum is deprecated
- support rest-client 2.1.0

### v0.7.0 / 2018-06-05

- deps: upgrade nokogiri to > 1.6 and ruby version >= 2.0

### v0.6.0 / 2017-07-23

- deps: upgrade rest-client to 2.x

### v0.5.0 / 2016-11-08

- feat: add crc check for uploading(enabled by default) and downloading(disabled by default)
- bug: fix file open mode for multipart

### v0.4.1 / 2016-07-19

- Support signature object url with STS

### v0.4.0 / 2016-05-19

- Enable copy objects of different buckets(but in the same region)

### v0.3.7

- Remove monkey patch for Hash

### v0.3.6

- Fix Zlib::Inflate in ruby-1.9.x
- Add function test(tests/) in travis CI
- Add Gem version badge
- Support IP endpoint

### v0.3.5

- Fix the issue that StreamWriter will read more bytes than wanted

### v0.3.4

- Fix handling gzip/deflate response
- Change the default accept-encoding to 'identity'
- Allow setting custom HTTP headers in get_object

### v0.3.3

- Fix object key problem in batch_delete

### v0.3.2

- Allow setting custom HTTP headers in put/append/resumable_upload
- Allow setting object acl in put/append

### v0.3.1

- Fix frozen string issue in OSSClient/STSClient config

### v0.3.0

- Add support for OSS Callback

### v0.2.0

- Add aliyun/sts
- OSS::Client support STS

### v0.1.8

- Fix StreamWriter string encoding problem
- Add ruby version and os version in User-Agent
- Some comments & examples refine

### v0.1.7

- Fix StreamWriter#inspect bug
- Fix wrong in README

### v0.1.6

- Required ruby version >= 1.9.3 due to 1.9.2 has String encoding
  compatibility problems
- Add travis & overalls
- Open source to github.com

### v0.1.5

- Add open_timeout and read_timeout config
- Fix a concurrency bug in resumable_upload/download

### v0.1.4

- Fix object key encoding problem
- Fix Content-Type problem
- Add list_uploads & abort_uploads methods
- Make resumable_upload/download faster by multi-threading
- Enable log rotate

### v0.1.3

- Include request id in exception message

### v0.1.2

- Fix yard doc unresolved link

### v0.1.1

- Add README.md CHANGELOG.md in gem
