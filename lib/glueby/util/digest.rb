module Glueby
  module Util
    module Digest
      # Hash content with specified digest algorithm
      #
      # @param content [String] content to be hashed
      # @param digest [Symbol] The symbol represents algorithm used for hashing. :sha256, :double_sha256, :none are available
      # @return [String] hex string hashed from content
      def digest_content(content, digest)
        case digest&.downcase
        when :sha256
          Tapyrus.sha256(content).bth
        when :double_sha256
          Tapyrus.double_sha256(content).bth
        when :none
          content
        else
          raise Glueby::Contract::Errors::UnsupportedDigestType
        end
      end
    end
  end
end
