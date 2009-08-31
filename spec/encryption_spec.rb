# encoding: utf-8
require "tempfile"

require File.join(File.expand_path(File.dirname(__FILE__)), "spec_helper") 

describe "Document encryption" do

  describe "Password padding" do

    include Prawn::Document::Encryption

    it "should truncate long passwords" do
      pw = "Long long string" * 30
      padded = pad_password(pw)
      padded.length.should == 32
      padded.should == pw[0, 32]
    end

    it "should pad short passwords" do
      pw = "abcd"
      padded = pad_password(pw)
      padded.length.should == 32
      padded.should == pw + Prawn::Document::Encryption::PasswordPadding[0, 28]
    end

    it "should fully pad null passwords" do
      pw = ""
      padded = pad_password(pw)
      padded.length.should == 32
      padded.should == Prawn::Document::Encryption::PasswordPadding
    end

  end
  
  describe "Setting permissions" do
    
    def doc_with_permissions(permissions)
      pdf = Prawn::Document.new
      pdf.encrypt_document(:permissions => permissions)
      pdf
    end

    it "should default to full permissions" do
      doc_with_permissions({}).permissions_value.should == 0xFFFFFFFF
      doc_with_permissions(:print_document     => true,
                           :modify_contents    => true,
                           :copy_contents      => true,
                           :modify_annotations => true).permissions_value.
        should == 0xFFFFFFFF
    end

    it "should clear the appropriate bits for each permission flag" do
      doc_with_permissions(:print_document => false).permissions_value.
        should == 0b1111_1111_1111_1111_1111_1111_1111_1011
      doc_with_permissions(:modify_contents => false).permissions_value.
        should == 0b1111_1111_1111_1111_1111_1111_1111_0111
      doc_with_permissions(:copy_contents => false).permissions_value.
        should == 0b1111_1111_1111_1111_1111_1111_1110_1111
      doc_with_permissions(:modify_annotations => false).permissions_value.
        should == 0b1111_1111_1111_1111_1111_1111_1101_1111
    end

  end

end
