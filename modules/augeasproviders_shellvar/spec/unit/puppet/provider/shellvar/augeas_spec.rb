#!/usr/bin/env rspec

require 'spec_helper'

provider_class = Puppet::Type.type(:shellvar).provider(:augeas)

describe provider_class do
  let(:unset_seq?) { subject.unset_seq? }

  context "with empty file" do
    let(:tmptarget) { aug_fixture("empty") }
    let(:target) { tmptarget.path }

    it "should create simple new entry" do
      apply!(Puppet::Type.type(:shellvar).new(
        :name     => "ENABLE",
        :value    => "true",
        :target   => target,
        :provider => "augeas"
      ))

      augparse(target, "Shellvars.lns", '
        { "ENABLE" = "true" }
      ')
    end

    it "should create new entry with multiple values as string" do
      apply!(Puppet::Type.type(:shellvar).new(
        :name       => "PORTS",
        :value      => ["123", "456", 789],
        :array_type => "string",
        :target     => target,
        :provider   => "augeas"
      ))

      augparse(target, "Shellvars.lns", '
        { "PORTS" = "\"123 456 789\"" }
      ')
    end

    it "should create new entry with multiple values as array" do
      apply!(Puppet::Type.type(:shellvar).new(
        :name       => "PORTS",
        :value      => ["123", "456", "789"],
        :array_type => "array",
        :target     => target,
        :provider   => "augeas"
      ))

      augparse(target, "Shellvars.lns", '
        { "PORTS"
          { "1" = "123" }
          { "2" = "456" }
          { "3" = "789" } }
      ')
    end

    it "should create new entry with comment" do
      apply!(Puppet::Type.type(:shellvar).new(
        :name     => "ENABLE",
        :value    => "true",
        :comment  => "test",
        :target   => target,
        :provider => "augeas"
      ))

      augparse(target, "Shellvars.lns", '
        { "#comment" = "ENABLE: test" }
        { "ENABLE" = "true" }
      ')
    end

    it "should create new entry as unset" do
      apply!(Puppet::Type.type(:shellvar).new(
        :ensure   => "unset",
        :name     => "ENABLE",
        :target   => target,
        :provider => "augeas"
      ))

      if unset_seq?
        augparse(target, "Shellvars.lns", '
          { "@unset" { "1" = "ENABLE" } }
        ')
      else
        augparse(target, "Shellvars.lns", '
          { "@unset" = "ENABLE" }
        ')
      end
    end

    it "should create new entry as unset with comment" do
      apply!(Puppet::Type.type(:shellvar).new(
        :ensure   => "unset",
        :name     => "ENABLE",
        :comment  => "test",
        :target   => target,
        :provider => "augeas"
      ))

      if unset_seq?
        augparse(target, "Shellvars.lns", '
          { "#comment" = "ENABLE: test" }
          { "@unset" { "1" = "ENABLE" } }
        ')
      else
        augparse(target, "Shellvars.lns", '
          { "#comment" = "ENABLE: test" }
          { "@unset" = "ENABLE" }
        ')
      end
    end

    it "should create new entry as exported" do
      apply!(Puppet::Type.type(:shellvar).new(
        :ensure   => "exported",
        :name     => "ENABLE",
        :value    => "true",
        :target   => target,
        :provider => "augeas"
      ))

      augparse(target, "Shellvars.lns", '
        { "ENABLE" = "true" { "export" } }
      ')
    end

    # GH #8
    it "should create new entry as exported with comment" do
      apply!(Puppet::Type.type(:shellvar).new(
        :ensure   => "exported",
        :name     => "ENABLE",
        :value    => "true",
        :comment  => "this is exported",
        :target   => target,
        :provider => "augeas"
      ))

      augparse(target, "Shellvars.lns", '
        { "#comment" = "ENABLE: this is exported" }
        { "ENABLE" = "true" { "export" } }
      ')
    end
  end

  context "with two empty files" do
    let(:tmptarget) { aug_fixture("empty") }
    let(:target) { tmptarget.path }
    let(:tmptarget2) { aug_fixture("empty") }
    let(:target2) { tmptarget2.path }

    it "should create two simple new entry" do
      apply!(Puppet::Type.type(:shellvar).new(
        :name     => "ENABLE in #{target}",
        :value    => "true",
        :provider => "augeas"
      ),
        Puppet::Type.type(:shellvar).new(
        :name     => "ENABLE in #{target2}",
        :value    => "true",
        :provider => "augeas"
      ))

      augparse(target, "Shellvars.lns", '
        { "ENABLE" = "true" }
      ')
      augparse(target2, "Shellvars.lns", '
        { "ENABLE" = "true" }
      ')
    end
  end

  context "with full file" do
    let(:tmptarget) { aug_fixture("full") }
    let(:target) { tmptarget.path }

    it "should create new entry next to commented out entry" do
      apply!(Puppet::Type.type(:shellvar).new(
        :name     => "SYNC_HWCLOCK",
        :value    => "yes",
        :target   => target,
        :provider => "augeas"
      ))

      aug_open(target, "Shellvars.lns") do |aug|
        aug.get("SYNC_HWCLOCK[preceding-sibling::#comment[.='SYNC_HWCLOCK=no']]").should == "yes"
      end
    end

    it "should replace comment with new entry" do
      apply!(Puppet::Type.type(:shellvar).new(
        :name      => "SYNC_HWCLOCK",
        :value     => "yes",
        :uncomment => true,
        :target    => target,
        :provider  => "augeas"
      ))

      aug_open(target, "Shellvars.lns") do |aug|
        aug.get("SYNC_HWCLOCK").should == "yes"
      end
    end

    it "should uncomment entry" do
      apply!(Puppet::Type.type(:shellvar).new(
        :name      => "SYNC_HWCLOCK",
        :ensure    => "present",
        :uncomment => true,
        :target    => target,
        :provider  => "augeas"
      ))

      aug_open(target, "Shellvars.lns") do |aug|
        aug.get("SYNC_HWCLOCK").should == "no"
      end
    end

    it "should delete entries" do
      apply!(Puppet::Type.type(:shellvar).new(
        :name     => "RETRIES",
        :ensure   => "absent",
        :target   => target,
        :provider => "augeas"
      ))

      aug_open(target, "Shellvars.lns") do |aug|
        aug.match("RETRIES").should == []
        aug.match("#comment[. =~ regexp('RETRIES:.*')]").should == []
      end
    end

    it "should delete unset entries" do
      apply!(Puppet::Type.type(:shellvar).new(
        :name     => "EXAMPLE_U",
        :ensure   => "absent",
        :target   => target,
        :provider => "augeas"
      ))

      aug_open(target, "Shellvars.lns") do |aug|
        aug.match("EXAMPLE_U").should == []
        if unset_seq?
          aug.match("@unset[*='EXAMPLE_U']").should == []
        else
          aug.match("@unset[.='EXAMPLE_U']").should == []
        end
      end
    end

	it "should uncomment value and append" do
      apply!(Puppet::Type.type(:shellvar).new(
        :name         => "LS_JAVA_OPTS",
        :value        => ["option2", "option3"],
        :array_append => true,
        :uncomment    => true,
        :target       => target,
        :provider     => "augeas"
      ))

      augparse_filter(target, "Shellvars.lns", "LS_JAVA_OPTS", '
        { "LS_JAVA_OPTS" = "\"option1 option2 option3\"" }
      ')
    end

	it "should uncomment values and append" do
      apply!(Puppet::Type.type(:shellvar).new(
        :name         => "LS_JAVA_OPTS_MULT",
        :value        => ["option2", "option3"],
        :array_append => true,
        :uncomment    => true,
        :target       => target,
        :provider     => "augeas"
      ))

      augparse_filter(target, "Shellvars.lns", "LS_JAVA_OPTS_MULT", '
        { "LS_JAVA_OPTS_MULT" = "\"option1 option2 option3\"" }
      ')
    end

    describe "when updating value" do
      it "should change unquoted value" do
        apply!(Puppet::Type.type(:shellvar).new(
          :name     => "RETRIES",
          :value    => "1",
          :target   => target,
          :provider => "augeas"
        ))

        augparse_filter(target, "Shellvars.lns", "RETRIES", '
          { "RETRIES" = "1" }
        ')
      end

      it "should change quoted value" do
        apply!(Puppet::Type.type(:shellvar).new(
          :name     => "OPTIONS",
          :value    => "-p 3 -s",
          :target   => target,
          :provider => "augeas"
        ))

        augparse_filter(target, "Shellvars.lns", "OPTIONS", '
          { "OPTIONS" = "\"-p 3 -s\"" }
        ')
      end

      it "should leave single quotes as-is" do
        apply!(Puppet::Type.type(:shellvar).new(
          :name     => "OPTIONS_SINGLE",
          :value    => "3",
          :target   => target,
          :provider => "augeas"
        ))

        augparse_filter(target, "Shellvars.lns", "OPTIONS_SINGLE", '
          { "OPTIONS_SINGLE" = "\'3\'" }
        ')
      end

      it "should leave double quotes as-is" do
        apply!(Puppet::Type.type(:shellvar).new(
          :name     => "OPTIONS",
          :value    => "3",
          :target   => target,
          :provider => "augeas"
        ))

        augparse_filter(target, "Shellvars.lns", "OPTIONS", '
          { "OPTIONS" = "\"3\"" }
        ')
      end

      it "should automatically add quotes" do
        apply!(Puppet::Type.type(:shellvar).new(
          :name     => "RETRIES",
          :value    => "-p 3 -s",
          :target   => target,
          :provider => "augeas"
        ))

        augparse_filter(target, "Shellvars.lns", "RETRIES", '
          { "RETRIES" = "\"-p 3 -s\"" }
        ')
      end

      it "should add forced single quotes" do
        apply!(Puppet::Type.type(:shellvar).new(
          :name     => "RETRIES",
          :value    => "3",
          :quoted   => "single",
          :target   => target,
          :provider => "augeas"
        ))

        augparse_filter(target, "Shellvars.lns", "RETRIES", '
          { "RETRIES" = "\'3\'" }
        ')
      end

      it "should add forced double quotes" do
        apply!(Puppet::Type.type(:shellvar).new(
          :name     => "RETRIES",
          :value    => "3",
          :quoted   => "double",
          :target   => target,
          :provider => "augeas"
        ))

        augparse_filter(target, "Shellvars.lns", "RETRIES", '
          { "RETRIES" = "\"3\"" }
        ')
      end

      it "should error when removing necessary quotes" do
        txn = apply(Puppet::Type.type(:shellvar).new(
          :name     => "OPTIONS",
          :value    => "-p 3",
          :quoted   => "false",
          :target   => target,
          :provider => "augeas"
        ))

        txn.any_failed?.should_not == nil
        logs_num = Puppet::Util::Package.versioncmp(Puppet.version, '3.4.0') >= 0 ? 1 : 0
        @logs[logs_num].level.should == :err
        @logs[logs_num].message.include?('Failed to save').should == true
      end

      it "should update string array value as auto string" do
        apply!(Puppet::Type.type(:shellvar).new(
          :name       => "STR_LIST",
          :value      => ["foo", "baz"],
          :array_type => 'auto',
          :target     => target,
          :provider   => "augeas"
        ))

        augparse_filter(target, "Shellvars.lns", "STR_LIST", '
          { "STR_LIST" = "\"foo baz\"" }
        ')
      end

      it "should update string array value as array" do
        apply!(Puppet::Type.type(:shellvar).new(
          :name       => "STR_LIST",
          :value      => ["foo", "baz"],
          :array_type => 'array',
          :target     => target,
          :provider   => "augeas"
        ))

        augparse_filter(target, "Shellvars.lns", "STR_LIST", '
          { "STR_LIST"
            { "1" = "foo" }
            { "2" = "baz" } }
        ')
      end

      it "should update array array value as auto array" do
        apply!(Puppet::Type.type(:shellvar).new(
          :name       => "LST_LIST",
          :value      => ["foo", "baz"],
          :array_type => 'auto',
          :target     => target,
          :provider   => "augeas"
        ))

        augparse_filter(target, "Shellvars.lns", "LST_LIST", '
          { "LST_LIST"
            { "1" = "foo" }
            { "2" = "baz" } }
        ')
      end

      it "should update array array value as string" do
        apply!(Puppet::Type.type(:shellvar).new(
          :name       => "LST_LIST",
          :value      => ["foo", "baz"],
          :array_type => 'string',
          :target     => target,
          :provider   => "augeas"
        ))

        augparse_filter(target, "Shellvars.lns", "LST_LIST", '
          { "LST_LIST" = "\"foo baz\"" }
        ')
      end
    end

    describe "when using array_append" do
      it "should not remove existing values" do
        apply!(Puppet::Type.type(:shellvar).new(
          :name         => "STR_LIST",
          :value        => ["foo", "fooz"],
          :array_append => true,
          :target       => target,
          :provider     => "augeas"
        ))

        augparse_filter(target, "Shellvars.lns", "STR_LIST", '
          { "STR_LIST" = "\"foo bar baz fooz\"" }
        ')
      end

      it "should set value as exported" do
        apply!(Puppet::Type.type(:shellvar).new(
          :ensure       => "exported",
          :name         => "STR_LIST",
          :value        => ["bar", "qux"],
          :array_append => true,
          :target       => target,
          :provider     => "augeas"
        ))

        aug_open(target, "Shellvars.lns") do |aug|
          aug.get("STR_LIST").should == '"foo bar baz qux"'
          aug.match("STR_LIST/export").should_not == []
        end
      end
    end

    describe "when using array_append with ensure absent" do
      it "should only remove specified values" do
        apply!(Puppet::Type.type(:shellvar).new(
          :name         => "STR_LIST",
          :value        => ["fooz", "bar"],
          :ensure       => "absent",
          :array_append => true,
          :target       => target,
          :provider     => "augeas"
        ))

        augparse_filter(target, "Shellvars.lns", "STR_LIST", '
          { "STR_LIST" = "\"foo baz\"" }
        ')
      end
    end

    describe "when updating comment" do
      it "should add comment" do
        apply!(Puppet::Type.type(:shellvar).new(
          :name     => "OPTIONS",
          :comment  => "test comment",
          :target   => target,
          :provider => "augeas"
        ))

        augparse_filter(target, "Shellvars.lns", '*[following-sibling::OPTIONS]', '
            { "#comment" = "OPTIONS: test comment" }
        ')
      end

      it "should change comment" do
        apply!(Puppet::Type.type(:shellvar).new(
          :name     => "RETRIES",
          :comment  => "Never gonna give you up",
          :target   => target,
          :provider => "augeas"
        ))

        aug_open(target, "Shellvars.lns") do |aug|
          aug.match("#comment[. = 'retry setting']").should_not == []
          aug.match("#comment[. = 'RETRIES: Never gonna give you up']").should_not == []
        end
      end

      it "should remove comment" do
        apply!(Puppet::Type.type(:shellvar).new(
          :name     => "RETRIES",
          :comment  => "",
          :target   => target,
          :provider => "augeas"
        ))

        aug_open(target, "Shellvars.lns") do |aug|
          aug.match("#comment[. =~ regexp('RETRIES:.*')]").should == []
          aug.match("#comment[. = 'retry setting']").should_not == []
        end
      end
    end

    it "should set value as unset" do
      apply!(Puppet::Type.type(:shellvar).new(
        :ensure   => "unset",
        :name     => "EXAMPLE",
        :target   => target,
        :provider => "augeas"
      ))

      aug_open(target, "Shellvars.lns") do |aug|
        aug.match("EXAMPLE").should == []
        aug.match("@unset").size.should == 2
      end
    end

    it "should set value as unset from exported" do
      apply!(Puppet::Type.type(:shellvar).new(
        :ensure   => "unset",
        :name     => "EXAMPLE_E",
        :target   => target,
        :provider => "augeas"
      ))

      aug_open(target, "Shellvars.lns") do |aug|
        aug.match("EXAMPLE_E").should == []
        aug.match("@unset").size.should == 2
      end
    end

    it "should set value as exported" do
      apply!(Puppet::Type.type(:shellvar).new(
        :ensure   => "exported",
        :name     => "EXAMPLE",
        :value    => "foo",
        :target   => target,
        :provider => "augeas"
      ))

      aug_open(target, "Shellvars.lns") do |aug|
        aug.match("EXAMPLE/export").should_not == []
      end
    end

    it "should set array value as exported" do
      apply!(Puppet::Type.type(:shellvar).new(
        :ensure   => "exported",
        :name     => "LST_LIST",
        :target   => target,
        :provider => "augeas"
      ))

      aug_open(target, "Shellvars.lns") do |aug|
        aug.match("LST_LIST/export").should_not == []
      end
    end

    it "should set value as exported from unset" do
      apply!(Puppet::Type.type(:shellvar).new(
        :ensure   => "exported",
        :name     => "EXAMPLE_U",
        :value    => "foo",
        :target   => target,
        :provider => "augeas"
      ))

      aug_open(target, "Shellvars.lns") do |aug|
        if unset_seq?
          aug.match("@unset[*='EXAMPLE_U']").should == []
        else
          aug.match("@unset[.='EXAMPLE_U']").should == []
        end
        aug.match("EXAMPLE_U/export").should_not == []
      end
    end

    it "should un-unset value" do
      apply!(Puppet::Type.type(:shellvar).new(
        :ensure   => "present",
        :name     => "EXAMPLE_U",
        :value    => "foo",
        :target   => target,
        :provider => "augeas"
      ))

      aug_open(target, "Shellvars.lns") do |aug|
        if unset_seq?
          aug.match("@unset[*='EXAMPLE_U']").should == []
        else
          aug.match("@unset[.='EXAMPLE_U']").should == []
        end
        aug.match("EXAMPLE_U/export").should == []
        aug.get("EXAMPLE_U").should == 'foo'
      end
    end

    it "should un-export value" do
      apply!(Puppet::Type.type(:shellvar).new(
        :ensure   => "present",
        :name     => "EXAMPLE_E",
        :value    => "foo",
        :target   => target,
        :provider => "augeas"
      ))

      aug_open(target, "Shellvars.lns") do |aug|
        aug.match("EXAMPLE_E/export").should == []
        aug.get("EXAMPLE_E").should == 'foo'
      end
    end
  end

  # Only test multiline when it is supported in Shellvars
  if provider_class.parsed_as?("FOO=\"bar\nbaz\"\n", '/FOO', 'Shellvars.lns')
    context "with full file containing multiline entries" do
      let(:tmptarget) { aug_fixture("full_multiline") }
      let(:target) { tmptarget.path }

      describe "when updating value" do
        it "should update value in multiline string" do
          apply!(Puppet::Type.type(:shellvar).new(
            :name       => "ML_LIST",
            :value      => ["foo", "123", "baz"],
            :array_type => 'string',
            :target     => target,
            :provider   => "augeas"
          ))

          if provider_class.aug_handler.respond_to? :text_store \
           and provider_class.parsed_as?("FOO=\"bar\nbaz\"\n", '/FOO/value', 'Shellvars_list.lns')
            augparse_filter(target, "Shellvars.lns", "ML_LIST", '
              { "ML_LIST" = "\"foo
  123
baz\"" }
            ')
          else
            # No support for clean multiline replacements without store/retrieve
            augparse_filter(target, "Shellvars.lns", "ML_LIST", '
              { "ML_LIST" = "\"foo 123 baz\"" }
            ')
          end
        end
      end

      describe "when using array_append" do
        it "should not remove existing values in multiline entry" do
          apply!(Puppet::Type.type(:shellvar).new(
            :name         => "ML_LIST",
            :value        => ["foo", "fooz"],
            :array_append => true,
            :target       => target,
            :provider     => "augeas"
          ))

          if provider_class.aug_handler.respond_to? :text_store \
           and provider_class.parsed_as?("FOO=\"bar\nbaz\"\n", '/FOO/value', 'Shellvars_list.lns')
            augparse_filter(target, "Shellvars.lns", "ML_LIST", '
              { "ML_LIST" = "\"foo
  bar
baz fooz\"" }
            ')
          else
            # No support for clean multiline replacements without store/retrieve
            augparse_filter(target, "Shellvars.lns", "ML_LIST", '
              { "ML_LIST" = "\"foo bar baz fooz\"" }
            ')
          end
        end
      end

      describe "when using array_append with ensure absent" do
        it "should only remove specified values in multiline entry" do
          apply!(Puppet::Type.type(:shellvar).new(
            :name         => "ML_LIST",
            :value        => ["fooz", "bar"],
            :ensure       => "absent",
            :array_append => true,
            :target       => target,
            :provider     => "augeas"
          ))

          if provider_class.aug_handler.respond_to? :text_store \
           and provider_class.parsed_as?("FOO=\"bar\nbaz\"\n", '/FOO/value', 'Shellvars_list.lns')
            augparse_filter(target, "Shellvars.lns", "ML_LIST", '
              { "ML_LIST" = "\"foo
  baz\"" }
            ')
          else
            # No support for clean multiline replacements without store/retrieve
            augparse_filter(target, "Shellvars.lns", "ML_LIST", '
              { "ML_LIST" = "\"foo baz\"" }
            ')
          end
        end
      end
    end
  end

  context "with broken file" do
    let(:tmptarget) { aug_fixture("broken") }
    let(:target) { tmptarget.path }

    it "should fail to load" do
      txn = apply(Puppet::Type.type(:shellvar).new(
        :name     => "RETRIES",
        :value    => "1",
        :target   => target,
        :provider => "augeas"
      ))

      txn.any_failed?.should_not == nil
      @logs.first.level.should == :err
      @logs.first.message.include?(target).should == true
    end
  end

  context "with commented file" do
    let(:tmptarget) { aug_fixture("commented") }
    let(:target) { tmptarget.path }

    it "should create simple new entry" do
      apply!(Puppet::Type.type(:shellvar).new(
        :name     => "UMASK",
        :value    => "0770",
        :target   => target,
        :provider => "augeas"
      ))

      augparse(target, "Shellvars.lns", '
        { "#comment" = "UMASK sets the initial shell file creation mode mask.  See umask(1)." }
        { "UMASK" = "0770" }
      ')
    end
  end
end
