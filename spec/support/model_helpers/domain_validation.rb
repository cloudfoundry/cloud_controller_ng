module VCAP::CloudController
  shared_examples_for "domain validation" do
    context "when the name is not present" do
      before { subject.name = nil }

      it { should_not be_valid }

      it "fails to validate" do
        subject.validate
        expect(subject.errors[:name]).to include(:presence)
      end
    end

    context "when there's another domain with the same name" do
      it "fails to validate" do
        other_domain = described_class.make()
        other_domain.name = subject.name
        expect(other_domain).to_not be_valid
        expect(other_domain.errors[:name]).to include(:unique)
      end
    end

    describe "name format validation" do
      it "should accept a two level domain" do
        subject.name = "a.com"
        subject.should be_valid
      end

      it "should accept a three level domain" do
        subject.name = "a.b.com"
        subject.should be_valid
      end

      it "should accept a four level domain" do
        subject.name = "a.b.c.com"
        subject.should be_valid
      end

      it "should accept a domain with a 2 char top level domain" do
        subject.name = "b.c.au"
        subject.should be_valid
      end

      it "should not allow a one level domain" do
        subject.name = "com"
        subject.should_not be_valid
      end

      it "should not allow a domain without a host" do
        subject.name = ".com"
        subject.should_not be_valid
      end

      it "should not allow a domain with a trailing dot" do
        subject.name = "a.com."
        subject.should_not be_valid
      end

      it "should not allow a domain with a leading dot" do
        subject.name = ".b.c.com"
        subject.should_not be_valid
      end

      it "should allow a domain with a single char top level domain" do
        subject.name = "b.c.d"
        subject.should be_valid
      end

      it "should allow a domain with a 6 char top level domain" do
        subject.name = "b.c.abcefg"
        subject.should be_valid
      end

      it "should not allow a domain with > 255 characters" do
        subdomain = "a" * 63
        subject.name = "#{subdomain}.#{subdomain}.#{subdomain}.#{subdomain}"
        subject.should be_valid

        subject.name = "#{subdomain}.#{subdomain}.#{subdomain}.#{subdomain}x"
        subject.should_not be_valid
      end

      it "should not allow a subdomain with > 63 characters" do
        subdomain = "a" * 63
        subject.name = "#{subdomain}.#{subdomain}"
        subject.should be_valid

        subdomain = "a" * 63
        subject.name = "#{subdomain}x.#{subdomain}"
        subject.should_not be_valid
      end

      it "should permit whitespace but strip it out" do
        subject.name = " foo.com "
        subject.should be_valid
        subject.name.should == "foo.com"
      end
    end

    context "domain overlapping" do
      context "when the domain exists in a different casing" do
        before do
          PrivateDomain.make name: "foo.com"
          subject.name = "FoO.CoM"
        end

        it { should_not be_valid }
      end

      context "when the name is foo.com and another org has bar.foo.com" do
        before do
          PrivateDomain.make name: "bar.foo.com"
          subject.name = "foo.com"
        end

        # this is kind of wonky behavior but it's pending further
        # simplification (i.e. only allowing top-level domains)
        it { should be_valid }
      end

      context "when the name is bar.foo.com and another org has foo.com" do
        before do
          PrivateDomain.make name: "foo.com"
          subject.name = "bar.foo.com"
        end

        it { should_not be_valid }
      end

      context "when the name is baz.bar.foo.com and another org has bar.foo.com" do
        before do
          PrivateDomain.make name: "bar.foo.com"
          subject.name = "baz.bar.foo.com"
        end

        it { should_not be_valid }
      end

      context "when the name is foo.com and bar.foo.com is a shared domain" do
        before do
          SharedDomain.make name: "bar.foo.com"
          subject.name = "foo.com"
        end

        # this is kind of wonky behavior but it's pending further
        # simplification (i.e. only allowing top-level domains)
        it { should be_valid }
      end

      context "when the name is bar.foo.com and foo.com is a shared domain" do
        before do
          SharedDomain.make name: "foo.com"
          subject.name = "bar.foo.com"
        end

        it { should_not be_valid }
      end

      context "when the name is baz.bar.foo.com and bar.foo.com is a shared domain" do
        before do
          SharedDomain.make name: "bar.foo.com"
          subject.name = "baz.bar.foo.com"
        end

        it { should_not be_valid }
      end
    end
  end
end
