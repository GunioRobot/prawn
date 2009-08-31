# encoding: utf-8
require "tempfile"

require File.join(File.expand_path(File.dirname(__FILE__)), "spec_helper") 

describe "Document encryption" do
  
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
