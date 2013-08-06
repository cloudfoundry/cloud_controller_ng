require "spec_helper"

module VCAP::CloudController
  describe Models::Buildpack, type: :model do
    it_behaves_like "a CloudController model", {
        :required_attributes => [:url, :name],
        :unique_attributes => [:name]
    }

    describe "validates_git_url" do
      before do
        subject.name = "test-pack"
      end

      it "does not allow a nil git url" do
        subject.url = nil
        expect(subject).to_not be_valid
      end

      it "allows a public git url" do
        subject.url = "git://example.com/foo.git"
        expect(subject).to be_valid
      end

      it "allows a public http url" do
        subject.url = "http://example.com/foo"
        expect(subject).to be_valid
      end

      it "does not allow a private git url" do
        subject.url = "git@example.com:foo.git"
        expect(subject).not_to be_valid
      end

      it "does not allow a private git url with ssh schema" do
        subject.url = "ssh://git@example.com:foo.git"
        expect(subject).not_to be_valid
      end

      it "does not allow a non-url string" do
        subject.url =  "Hello, world!"
        expect(subject).not_to be_valid
      end
    end
  end
end
