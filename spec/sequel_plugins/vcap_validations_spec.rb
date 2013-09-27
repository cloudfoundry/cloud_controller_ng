require "spec_helper"

describe "Sequel::Plugins::VcapValidations" do
  before do
    @c = Class.new(Sequel::Model) do
      attr_accessor :val
      def self.set_validations(&block)
        define_method(:validate, &block)
      end
    end
    @c.plugin :vcap_validations
    @m = @c.new
  end

  describe "validates_url" do
    before do
      @c.set_validations { validates_url(:val) }
    end

    it "should allow a http url" do
      @m.val = "http://foo.com/bla";
      @m.should be_valid
    end

    it "should allow a https url" do
      @m.val = "https://foo.com/bla";
      @m.should be_valid
    end

    it "should not allow an invalid url" do
      @m.val = "bad url"
      @m.should_not be_valid
    end

    it "should not allow a file url" do
      @m.val = "file://bla"
      @m.should_not be_valid
    end

    it "should allow a nil url" do
      @m.val = nil
      @m.should be_valid
    end

    it "should not allow an empty url" do
      @m.val = ""
      @m.should_not be_valid
    end

    it "should not allow a url with only spaces" do
      @m.val = " "
      @m.should_not be_valid
    end
  end

  describe "validates_email" do
    before do
      @c.set_validations { validates_email(:val) }
    end

    it "should allow a valid email" do
      @m.val = "some_guy@foo.com"
      @m.should be_valid
    end

    it "should not allow an email with no domain" do
      @m.val = "some_guy"
      @m.should_not be_valid
    end

    it "should not allow an email with no user" do
      @m.val = "@somedomain.com"
      @m.should_not be_valid
    end

    it "should not allow a malformed email with multiple @" do
      @m.val = "foo@some@domain.com"
      @m.should_not be_valid
    end

    it "should allow a nil email" do
      @m.val = nil
      @m.should be_valid
    end

    it "should not allow an empty email" do
      @m.val = ""
      @m.should_not be_valid
    end

    it "should not allow an email with only spaces" do
      @m.val = " "
      @m.should_not be_valid
    end
  end
end
