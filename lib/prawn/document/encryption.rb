# encoding: utf-8
#
# encryption.rb : Implements encrypted PDF and access permissions.
#
# Copyright August 2008, Brad Ediger. All Rights Reserved.
#
# This is free software. Please see the LICENSE and COPYING files for details.

require 'digest/md5'
require 'rc4'
require 'prawn/byte_string'

module Prawn
  class Document
    
    # Implements PDF encryption (password protection and permissions) as
    # specified in the PDF Reference, version 1.3, section 3.5 "Encryption".
    module Encryption
      
      # TODO: doc
      #
      # The following permissions can be specified:
      #
      # [+:print_document+] Print document.
      # [+:modify_document+] Modify contents of document (other than text
      #     annotations and interactive form fields).
      # [+:copy_contents+] Copy text and graphics from document.
      # [+:modify_annotations+] Add or modify text annotations and interactive
      #     form fields.
      def encrypt_document(options={})
        @user_password = options.delete(:user_password) || ""
        @owner_password = options.delete(:owner_password) || @user_password
        self.permissions = options.delete(:permissions) || {}

        # Shove the necessary entries in the trailer.
        @trailer[:Encrypt] = encryption_dictionary
        @encrypted = true
      end
      
      # Provides the values for the trailer encryption dictionary.
      def encryption_dictionary
        { :Filter => :Standard, # default PDF security handler
          :V      => 1,         # "Algorithm 3.1", PDF reference 1.3
          :R      => 2,         # Revision 2 of the algorithm
          :O      => ByteString.new(owner_password_hash),
          :U      => ByteString.new(user_password_hash),
          :P      => permissions_value }
      end

      PasswordPadding = 
        "28BF4E5E4E758A4164004E56FFFA01082E2E00B6D0683E802F0CA9FE6453697A".
        scan(/../).map{|x| x.to_i(16)}.pack("c*")
      
      # Pads or truncates a password to 32 bytes as per Alg 3.2.
      def pad_password(password)
        password = password[0, 32]
        password + PasswordPadding[0, 32 - password.length]
      end

      def user_encryption_key
        @user_encryption_key ||= begin
          md5 = Digest::MD5.new
          md5 << pad_password(@user_password)
          md5 << owner_password_hash
          md5 << [permissions_value].pack("V")
          md5.digest[0, 5]
        end
      end

      # The O (owner) value in the encryption dictionary. Algorithm 3.3.
      def owner_password_hash
        @owner_password_hash ||= begin
          key = Digest::MD5.digest(pad_password(@owner_password))[0, 5]
          RubyRc4.new(key).encrypt(pad_password(@user_password))
        end
      end

      # The U (user) value in the encryption dictionary. Algorithm 3.4.
      def user_password_hash
        RubyRc4.new(user_encryption_key).encrypt(PasswordPadding)
      end

      # Flags in the permissions word, numbered as LSB = 1
      PermissionsBits = { :print_document     => 3,
                          :modify_contents    => 4,
                          :copy_contents      => 5,
                          :modify_annotations => 6 }
      
      FullPermissions = 0b1111_1111_1111_1111_1111_1111_1111_1111

      def permissions=(perms={})
        @permissions ||= FullPermissions
        perms.each do |key, value|
          # 0-based bit number, from LSB
          bit_position = PermissionsBits[key] - 1

          if value # set bit
            @permissions |= (1 << bit_position)
          else # clear bit
            @permissions &= ~(1 << bit_position)
          end
        end
      end

      def permissions_value
        @permissions || FullPermissions
      end

      # Encrypts the given string under the given key, also requiring the
      # object ID and generation number of the reference.
      # See Algorithm 3.1.
      def self.encrypt_string(str, key, id, gen)
        # Convert ID and Gen number into little-endian truncated byte strings
        id = [id].pack('V')[0,3]
        gen = [gen].pack('V')[0,2]
        extended_key = "#{key}#{id}#{gen}"

        # Compute the RC4 key from the extended key and perform the encryption
        rc4_key = Digest::MD5.digest(extended_key)[0, 10]
        RubyRc4.new(rc4_key).encrypt(str)
      end
    end

  end

  # Like PdfObject, but returns an encrypted result if required.
  # For direct objects, requires the object identifier and generation number
  # from the indirect object referencing obj.
  def EncryptedPdfObject(obj, key, id, gen, in_content_stream=false)
    case obj
    when Array
      "[" << obj.map { |e|
          EncryptedPdfObject(e, key, id, gen, in_content_stream)
      }.join(' ') << "]"
    when Prawn::LiteralString
      # FIXME: encrypted?
      obj = obj.gsub(/[\\\n\(\)]/) { |m| "\\#{m}" }
      "(#{obj})"
    when Time
      # FIXME: encrypted?
      obj = obj.strftime("D:%Y%m%d%H%M%S%z").chop.chop + "'00'"
      obj = obj.gsub(/[\\\n\(\)]/) { |m| "\\#{m}" }
      "(#{obj})"
    when String
      PdfObject(
        ByteString.new(Document::Encryption.encrypt_string(obj, key, id, gen)),
        in_content_stream)
    when Hash
      output = "<< "
      obj.each do |k,v|
        unless String === k || Symbol === k
          raise Prawn::Errors::FailedObjectConversion,
            "A PDF Dictionary must be keyed by names"
        end
        output << PdfObject(k.to_sym, in_content_stream) << " " <<
                  EncryptedPdfObject(v, key, id, gen, in_content_stream) << "\n"
      end
      output << ">>"
    when Prawn::NameTree::Value
      PdfObject(obj.name) + " " +
        EncryptedPdfObject(obj.value, key, id, gen, in_content_stream)
    else # delegate back to PdfObject
      PdfObject(obj, in_content_stream)
    end
  end

  class Reference

    def encrypted_object(key)
      @on_encode.call(self) if @on_encode
      output = "#{@identifier} #{gen} obj\n" <<
               Prawn::EncryptedPdfObject(data, key, @identifier, gen) << "\n"
      if @stream
        output << "stream\n" <<
          Document::Encryption.encrypt_string(@stream, key, @identifier, gen) <<
          "\nendstream\n"
      end
      output << "endobj\n"
    end

  end
end
