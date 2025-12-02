# -*- encoding: utf-8 -*-

$LOAD_PATH.unshift(File.expand_path("../../../../lib", __FILE__))
require 'yaml'
require 'aliyun/oss'

# 初始化OSS Bucket
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

demo "Resumable upload" do
  puts "Generate file: /tmp/x, size: 100MB"
  # 生成一个100M的文件
  File.open('/tmp/x', 'w') do |f|
    (1..1024*1024).each{ |i| f.puts i.to_s.rjust(99, '0') }
  end

  cpt_file = '/tmp/x.cpt'
  File.delete(cpt_file) if File.exist?(cpt_file)

  # 上传一个100M的文件
  start = Time.now
  puts "Start upload: /tmp/x => resumable"
  bucket.resumable_upload(
    'resumable', '/tmp/x', :cpt_file => cpt_file) do |progress|
    puts "Progress: #{(progress * 100).round(2)} %"
  end
  puts "Upload complete. Cost: #{Time.now - start} seconds."

  # 测试方法：
  # 1. ruby examples/resumable_upload.rb
  # 2. 过几秒后用Ctrl-C中断上传
  # 3. ruby examples/resumable_upload.rb恢复上传
end
