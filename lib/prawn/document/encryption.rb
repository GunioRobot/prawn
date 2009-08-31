# encoding: utf-8
#
# encryption.rb : Implements encrypted PDF and access permissions.
#
# Copyright August 2008, Brad Ediger. All Rights Reserved.
#
# This is free software. Please see the LICENSE and COPYING files for details.

module Prawn
  class Document
    
    # Implements PDF encryption (password protection and permissions) as
    # specified in the PDF Reference, version 1.3, section 3.5 "Encryption".
    module Encryption
      
      # TODO: doc
      def encrypt_document(options={})
        # TODO: complete
        self.permissions = options.delete(:permissions) || {}
      end
      
      # Provides the values for the trailer encryption dictionary.
      def encryption_dictionary
        { :Filter => :Standard, # default PDF security handler
          :V      => 1,         # "Algorithm 3.1", PDF reference 1.3
          :R      => 2,         # Revision 2 of the algorithm
          :O      => owner_password_hash,
          :U      => user_password_hash,
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

      def owner_password_hash
        # TODO
      end

      def user_password_hash
        # TODO
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

    end

  end
end
