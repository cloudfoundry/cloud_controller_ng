require 'test/unit'
require File.dirname(__FILE__) + "/../../lib/multipart_parser/reader"
require File.dirname(__FILE__) + "/../fixtures/multipart"

module MultipartParser
  class ReaderTest < Test::Unit::TestCase
    def test_extract_boundary_value
      assert_raise(NotMultipartError) do
        not_multipart = "text/plain"
        Reader.extract_boundary_value(not_multipart)
      end

      assert_raise(NotMultipartError) do
        no_boundary = "multipart/form-data"
        Reader.extract_boundary_value(no_boundary)
      end

      valid_content_type = "multipart/form-data; boundary=9asdadsdfv"
      boundary = Reader.extract_boundary_value(valid_content_type)
      assert_equal "9asdadsdfv", boundary
    end

    def test_error_callback
      on_error_called = false
      reader = Reader.new("boundary")
      reader.on_error do |err|
        on_error_called = true
      end
      reader.write("not boundary atleast")
      assert on_error_called
    end

    def test_success_scenario
      fixture = Fixtures::Rfc1867.new
      reader = Reader.new(fixture.boundary)
      on_error_called = false
      parts = {}

      reader.on_error do |err|
        on_error_called = true
      end

      reader.on_part do |part|
        part_entry = {:part => part, :data => '', :ended => false}
        parts[part.name] = part_entry
        part.on_data do |data|
          part_entry[:data] << data
        end
        part.on_end do
          part_entry[:ended] = true
        end
      end

      reader.write(fixture.raw)

      assert !on_error_called
      assert reader.ended?

      assert_equal parts.size, fixture.parts.size
      assert parts.all? {|k, v| v[:ended]}

      field = parts['field1']
      assert !field.nil?
      assert_equal 'field1', field[:part].name
      assert_equal fixture.parts.first[:data], field[:data]

      file = parts['pics']
      assert !file.nil?
      assert_equal 'pics', file[:part].name
      assert_equal 'file1.txt', file[:part].filename
      assert_equal fixture.parts.last[:data], file[:data]
    end

    def test_long
      fixture = Fixtures::LongBoundary.new
      reader = Reader.new(fixture.boundary)
      on_error_called = false
      parts = {}

      reader.on_error do |err|
        on_error_called = true
      end

      reader.on_part do |part|
        part_entry = {:part => part, :data => '', :ended => false}
        parts[part.name] = part_entry
        part.on_data do |data|
          part_entry[:data] << data
        end
        part.on_end do
          part_entry[:ended] = true
        end
      end

      reader.write(fixture.raw)

      assert !on_error_called
      assert reader.ended?

      assert_equal parts.size, fixture.parts.size
      assert parts.all? {|k, v| v[:ended]}

      field = parts['field1']
      assert !field.nil?
      assert_equal 'field1', field[:part].name
      assert_equal fixture.parts.first[:data], field[:data]
    end
  end
end
