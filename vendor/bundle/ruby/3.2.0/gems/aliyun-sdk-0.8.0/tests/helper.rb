# -*- encoding: utf-8 -*-

module Aliyun
  module Test
    module Helper
      def random_string(n)
        (1...n).map { (65 + rand(26)).chr }.join + "\n"
      end

      def random_bytes(n)
        (1...n).map { rand(255).chr }.join + "\n"
      end
    end
  end
end