# -*- encoding: utf-8 -*-

$LOAD_PATH.unshift(File.expand_path("../../../../lib", __FILE__))
require 'yaml'
require 'json'
require 'aliyun/oss'

##
# 用户在上传文件时可以指定“上传回调”，这样在文件上传成功后OSS会向用户
# 提供的服务器地址发起一个HTTP POST请求，相当于一个通知机制。用户可以
# 在收到回调的时候做相应的动作。
# 1. 如何接受OSS的回调可以参考代码目录下的
#    rails/aliyun_oss_callback_server.rb
# 2. 只有put_object和resumable_upload支持上传回调

# 初始化OSS client
Aliyun::Common::Logging.set_log_level(Logger::DEBUG)
conf_file = '~/.oss.yml'
conf = YAML.load(File.read(File.expand_path(conf_file)))
bucket = Aliyun::OSS::Client.new(
  :endpoint => conf['endpoint'],
  :cname => conf['cname'],
  :access_key_id => conf['access_key_id'],
  :access_key_secret => conf['access_key_secret']).get_bucket(conf['bucket'])

# 辅助打印函数
def demo(msg)
  puts "######### #{msg} ########"
  puts
  yield
  puts "-------------------------"
  puts
end

demo "put object with callback" do
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
end

demo "resumable upload with callback" do
  callback = Aliyun::OSS::Callback.new(
    url: 'http://10.101.168.94:1234/callback',
    query: {user: 'resumable_upload'},
    body: 'bucket=${bucket}&object=${object}'
  )

  begin
    bucket.resumable_upload('files/world', '/tmp/x', callback: callback)
  rescue Aliyun::OSS::CallbackError => e
    puts "Callback failed: #{e.message}"
  end
end
