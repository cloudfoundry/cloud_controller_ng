require 'spec_helper'

describe StructuredError do

  it 'generates the correct hash' do
    exception = described_class.new('some msg', { 'foo' => 'bar' })

    begin
      # must raise to populate backtrace
      raise exception
    rescue => e
      expect(e.to_h).to eq({
         'description' => "some msg",
         'types' => ["StructuredError", "StandardError"],
         'backtrace' => e.backtrace,
         'source' => {
             'foo' => 'bar'
         }
      })
    end
  end

end