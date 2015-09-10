module VCAP::CloudController
  class Procfile
    class ParseError < StandardError; end

    def self.load(body)
      body = body.read if body.is_a? StringIO
      process(body)
    end

    def self.validate(body)
      body = body.read if body.is_a? StringIO
      process(body)
      body
    end

    def self.process(procfile)
      processes = procfile.gsub("\r\n", "\n").split("\n").each_with_object({}) do |line, hash|
        matches = line.match(/^(?<type>[A-Za-z0-9_-]+):\s*(?<command>.+)$/)
        hash[matches[:type].to_sym] = matches[:command] if matches
      end

      raise ParseError if processes.empty?
      processes
    end
  end
end
