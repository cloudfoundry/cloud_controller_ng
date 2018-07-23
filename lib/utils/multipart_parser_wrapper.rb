require 'multipart_parser/reader'

module VCAP
  class MultipartParserWrapper
    NEW_LINE = "\r\n".freeze

    def initialize(body:, boundary:)
      @body     = body
      @boundary = boundary
    end

    def next_part
      @chunks ||= parse(@body, @boundary)
      @chunks.next
    rescue StopIteration, ParseError
      nil
    end

    private

    def parse(body, boundary)
      parts = []

      reader = ::MultipartParser::Reader.new(boundary)

      reader.on_part do |part|
        p = []

        part.on_data do |partial_data|
          p << partial_data
        end

        parts << p
      end

      reader.write body

      unless reader.ended?
        raise ParseError.new('truncated multipart message')
      end

      parts.map(&:join).to_enum
    end
  end
end
