# frozen_string_literal: true

require 'minitest_helper'
require 'fog/xml'

# We expose accessors just for testing purposes
Fog::ToHashDocument.attr_accessor(:value, :stack)

describe Fog::ToHashDocument do
  before do
    @document = Fog::ToHashDocument.new
  end

  describe '#characters' do
    it 'appends characters to @value' do
      @document.characters('some text')
      _(@document.value).must_equal 'some text'
    end

    it 'strips whitespace from characters' do
      @document.characters('  some text  ')
      _(@document.value).must_equal 'some text'
    end
  end

  describe '#end_element' do
    before do
      @document.stack << {}
      @document.characters('some text')
    end

    it 'adds element with text content to the stack' do
      @document.end_element('element')

      expected = { element: 'some text' }
      _(@document.stack.last).must_equal(expected)
    end

    it 'can mutate the new empty value' do
      @document.end_element('element')

      _(@document.value).must_equal('')

      # Mutate the new empty value even when frozen string literals are enabled
      _(@document.characters('one'))
    end

    it 'adds empty string if element is empty and value is empty' do
      @document.value = ''

      @document.end_element('element')

      expected = { element: '' }
      _(@document.stack.last).must_equal(expected)
    end

    it 'adds nil if element has :i_nil attribute' do
      @document.stack.last[:i_nil] = 'true'
      @document.value = ''

      @document.end_element('element')

      expected = { element: nil }
      _(@document.stack.last).must_equal(expected)
    end
  end

  describe '#body' do
    it 'returns the first element of the stack' do
      @document.stack << { key: 'value' }

      expected = { key: 'value' }
      _(@document.body).must_equal(expected)
    end
  end

  describe '#response' do
    it 'returns the body' do
      @document.stack << { key: 'value' }

      expected = { key: 'value' }
      _(@document.response).must_equal(expected)
    end
  end

  describe '#start_element' do
    it 'parses attributes correctly' do
      @document.start_element('element', [%w[key value]])

      expected = { key: 'value' }
      _(@document.stack.last).must_equal(expected)
    end

    it 'handles elements without attributes' do
      @document.start_element('element')

      _(@document.stack.last).must_equal({})
    end

    it 'adds nested elements to the stack' do
      @document.start_element('parent')
      @document.start_element('child')

      _(@document.stack).must_equal([{ child: {} }, { child: {} }, {}])
    end

    it 'adds nested elements with attributes to the stack' do
      @document.start_element('parent')
      @document.start_element('child', [%w[key value]])
      expected = [
        { child: { key: 'value' } },
        { child: { key: 'value' } },
        { key: 'value' }
      ]

      _(@document.stack).must_equal(expected)
    end

    it 'handles multiple children elements correctly' do
      @document.start_element('parent')
      @document.start_element('child1')
      @document.end_element('child1')
      @document.start_element('child2', [%w[key value]])
      @document.end_element('child2')
      expected = {
        child1: '',
        child2: { key: 'value' }
      }

      _(@document.stack.first).must_equal(expected)
    end

    it 'handles text content within elements' do
      @document.start_element('parent')
      @document.characters('some text')
      @document.end_element('parent')

      expected = { parent: 'some text' }
      _(@document.stack.first).must_equal(expected)
    end
  end
end
