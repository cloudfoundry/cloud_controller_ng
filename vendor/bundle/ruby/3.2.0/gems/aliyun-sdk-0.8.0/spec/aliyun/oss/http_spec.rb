# -*- encoding: utf-8 -*-

require 'spec_helper'

module Aliyun
  module OSS

    describe HTTP do

      context HTTP::StreamWriter do
        it "should read out chunks that are written" do
          s = HTTP::StreamWriter.new do |sr|
            100.times { sr << "x" }
          end

          10.times do
            bytes, outbuf = 10, ''
            s.read(bytes, outbuf)
            expect(outbuf).to eq("x"*10)
          end

          outbuf = 'xxx'
          r = s.read(10, outbuf)
          expect(outbuf).to eq('')
          expect(r).to be nil

          r = s.read
          expect(outbuf.empty?).to be true
          expect(r).to eq('')
        end

        it "should convert chunk to string" do
          s = HTTP::StreamWriter.new do |sr|
            sr << 100 << 200
          end

          r = s.read
          expect(r).to eq("100200")
        end

        it "should encode string to bytes" do
          s = HTTP::StreamWriter.new do |sr|
            100.times { sr << "中" }
          end

          r = s.read(1)
          expect(r).to eq('中'.force_encoding(Encoding::ASCII_8BIT)[0])
          s.read(2)
          r = s.read(3)
          expect(r.force_encoding(Encoding::UTF_8)).to eq('中')

          bytes = (100 - 2) * 3
          outbuf = 'zzz'
          r = s.read(bytes, outbuf)
          expect(outbuf.size).to eq(bytes)
          expect(r.size).to eq(bytes)

          r = s.read
          expect(r).to eq('')
        end

        it "should read exactly bytes" do
          s = HTTP::StreamWriter.new do |sr|
            100.times { sr << 'x' * 10 }
          end

          r = s.read(11)
          expect(r.size).to eq(11)

          r = s.read(25)
          expect(r.size).to eq(25)

          r = s.read(900)
          expect(r.size).to eq(900)

          r = s.read(1000)
          expect(r.size).to eq(64)
        end

        it "should read with a correct crc" do
          content = "hello world"
          content_crc = Aliyun::OSS::Util.crc(content)
          s = HTTP::StreamWriter.new(true) do |sr|
            sr << content
          end

          r = s.read(content.size + 1)
          expect(r.size).to eq(content.size)
          expect(s.data_crc).to eq(content_crc)
        end

        it "should read with a correct crc when setting init_crc" do
          content = "hello world"
          init_crc = 100
          content_crc = Aliyun::OSS::Util.crc(content, init_crc)

          s = HTTP::StreamWriter.new(true, init_crc) do |sr|
            sr << content
          end

          r = s.read(content.size + 1)
          expect(r.size).to eq(content.size)
          expect(s.data_crc).to eq(content_crc)
        end
      end # StreamWriter

    end # HTTP
  end # OSS
end # Aliyun
