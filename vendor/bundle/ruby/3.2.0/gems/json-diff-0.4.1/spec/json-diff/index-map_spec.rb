require 'spec_helper'

describe JsonDiff do
  # AdditionIndexMap

  it "should be able to offset an index" do
    aim = JsonDiff::AdditionIndexMap.new(3)
    expect(aim.map(2)).to eql(2)
    expect(aim.map(3)).to eql(4)
    expect(aim.map(4)).to eql(5)
  end

  it "should be able to offset an index negatively" do
    rim = JsonDiff::RemovalIndexMap.new(3)
    expect(rim.map(2)).to eql(2)
    expect(rim.map(3)).to eql(2)
    expect(rim.map(4)).to eql(3)
  end

  # IndexMaps

  it "should be able to offset an index with a deletion and an insertion" do
    im = JsonDiff::IndexMaps.new
    im.removal(2)
    im.addition(4)
    expect(im.map(1)).to eql(1)
    expect(im.map(2)).to eql(1)
    expect(im.map(3)).to eql(2)
    expect(im.map(4)).to eql(3)
    expect(im.map(5)).to eql(5)
  end

  it "should be able to offset an index with an insertion and a deletion" do
    im = JsonDiff::IndexMaps.new
    im.addition(2)
    im.removal(4)
    expect(im.map(1)).to eql(1)
    expect(im.map(2)).to eql(3)
    expect(im.map(3)).to eql(3)
    expect(im.map(4)).to eql(4)
    expect(im.map(5)).to eql(5)
  end

end
