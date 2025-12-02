require 'spec_helper'

describe JsonDiff do
  it "should convert the root to a JSON pointer" do
    json_pointer = JsonDiff.json_pointer([])
    expect(json_pointer).to eql("")
  end

  it "should convert a path to a JSON pointer" do
    json_pointer = JsonDiff.json_pointer(["path", "to", 1, "soul"])
    expect(json_pointer).to eql("/path/to/1/soul")
  end

  it "should escape a path" do
    json_pointer = JsonDiff.json_pointer(["a/b", "c%d", "e^f", "g|h", "i\\j", "k\"l", " ", "m~n"])
    expect(json_pointer).to eql("/a~1b/c%d/e^f/g|h/i\\j/k\"l/ /m~0n")
  end

  it "should expand a path" do
    json_pointer = JsonDiff.json_pointer(["path", "to", 1, "soul"])
    json_pointer = JsonDiff.extend_json_pointer(json_pointer, "further")
    expect(json_pointer).to eql("/path/to/1/soul/further")
  end

  it "should expand an empty path" do
    json_pointer = JsonDiff.json_pointer([])
    json_pointer = JsonDiff.extend_json_pointer(json_pointer, "further")
    expect(json_pointer).to eql("/further")
  end
end
