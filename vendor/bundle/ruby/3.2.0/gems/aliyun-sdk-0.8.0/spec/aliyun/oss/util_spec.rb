# -*- encoding: utf-8 -*-

require 'spec_helper'

module Aliyun
  module OSS

    describe Util do
      # 测试对body content的md5编码是否正确
      it "should get correct content md5" do
        content = ""

        md5 = Util.get_content_md5(content)
        expect(md5).to eq("1B2M2Y8AsgTpgAmY7PhCfg==")

        content = "hello world"
        md5 = Util.get_content_md5(content)
        expect(md5).to eq("XrY7u+Ae7tCTyyK7j1rNww==")
      end

      # 测试签名是否正确
      it "should get correct signature" do
        key = 'helloworld'
        date = 'Fri, 30 Oct 2015 07:21:00 GMT'

        signature = Util.get_signature(key, 'GET', {'date' => date}, {})
        expect(signature).to eq("u8QKAAj/axKX4JhHXa5DYfYSPxE=")

        signature = Util.get_signature(
          key, 'PUT', {'date' => date}, {:path => '/bucket'})
        expect(signature).to eq("lMKrMCJIuGygd8UsdMA+S0QOAsQ=")

        signature = Util.get_signature(
          key, 'PUT',
          {'date' => date, 'x-oss-copy-source' => '/bucket/object-old'},
          {:path => '/bucket/object-new'})
        expect(signature).to eq("McYUmBaErN//yvE9voWRhCgvsIc=")

        signature = Util.get_signature(
          key, 'PUT',
          {'date' => date},
          {:path => '/bucket/object-new',
           :sub_res => {'append' => nil, 'position' => 0}})
        expect(signature).to eq("7Oh2wobzeg6dw/cWYbF/2m6s6qc=")
      end

      # 测试CRC计算是否正确
      it "should calculate a correct data crc" do
        content = ""
        crc = Util.crc(content)
        expect(crc).to eq(0)

        content = "hello world"
        crc = Util.crc(content)
        expect(crc).to eq(5981764153023615706)

        content = "test\0hello\1world\2!\3"
        crc = Util.crc(content)
        expect(crc).to eq(6745424696046691431)
      end

      # 测试CRC Combine计算是否正确
      it "should calculate a correct crc that crc_a combine with crc_b" do
        content_a = "test\0hello\1world\2!\3"
        crc_a = Util.crc(content_a)
        expect(crc_a).to eq(6745424696046691431)

        content_b = "hello world"
        crc_b = Util.crc(content_b)
        expect(crc_b).to eq(5981764153023615706)

        crc_c = Util.crc_combine(crc_a, crc_b, content_b.size)
        expect(crc_c).to eq(13027479509578346683)

        crc_ab = Util.crc(content_a + content_b)
        expect(crc_ab).to eq(crc_c)

        crc_ab = Util.crc(content_b, crc_a)
        expect(crc_ab).to eq(crc_c)
      end

      # 测试CRC校验和异常处理是否正确
      it "should check inconsistent crc" do
        expect {
          Util.crc_check(6745424696046691431, 6745424696046691431, 'put')
        }.not_to raise_error
        
        expect {
          Util.crc_check(6745424696046691431, 5981764153023615706, 'append')
        }.to raise_error(CrcInconsistentError, "The crc of append between client and oss is not inconsistent.")

        expect {
          Util.crc_check(6745424696046691431, -1, 'post')
        }.to raise_error(CrcInconsistentError, "The crc of post between client and oss is not inconsistent.")
      end

      it "should check bucket name valid" do
        expect {
          Util.ensure_bucket_name_valid('abc')
        }.not_to raise_error

        expect {
          Util.ensure_bucket_name_valid('abc123-321cba')
        }.not_to raise_error

        expect {
          Util.ensure_bucket_name_valid('abcdefghijklmnopqrstuvwxyz1234567890-0987654321zyxwuvtsrqponmlk')
        }.not_to raise_error

        #>63
        expect {
          Util.ensure_bucket_name_valid('abcdefghijklmnopqrstuvwxyz1234567890-0987654321zyxwuvtsrqponmlkj')
        }.to raise_error(ClientError, "The bucket name is invalid.")

        #<3
        expect {
          Util.ensure_bucket_name_valid('12')
        }.to raise_error(ClientError, "The bucket name is invalid.")
        
        #not [a-z0-9-]
        expect {
          Util.ensure_bucket_name_valid('Aabc')
        }.to raise_error(ClientError, "The bucket name is invalid.")

        expect {
          Util.ensure_bucket_name_valid('abc/')
        }.to raise_error(ClientError, "The bucket name is invalid.")

        expect {
          Util.ensure_bucket_name_valid('abc#')
        }.to raise_error(ClientError, "The bucket name is invalid.")

        expect {
          Util.ensure_bucket_name_valid('abc?')
        }.to raise_error(ClientError, "The bucket name is invalid.")

        #start & end not -
        expect {
          Util.ensure_bucket_name_valid('-abc')
        }.to raise_error(ClientError, "The bucket name is invalid.")

        expect {
          Util.ensure_bucket_name_valid('abc-')
        }.to raise_error(ClientError, "The bucket name is invalid.")
        
      end  

    end # Util

  end # OSS
end # Aliyun
