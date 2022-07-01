module Glueby
  module Util
    module Digest
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

      def valid_digest?(digest)
        case digest&.downcase
        when :sha256, :double_sha256, :none
          true
        else
          false
        end
      end
    end
  end
end
