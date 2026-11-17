require "openssl"

module Subetha
  module SslHelper
    def ssl_store
      @ssl_store ||= OpenSSL::X509::Store.new.tap(&:set_default_paths)
    end
  end
end
