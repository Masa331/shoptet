require 'net/http'

#TODO: keep_alive_timeout ?

class Shoptet
  class Request
    def self.get uri, headers
      attempt ||= 0
      attempt += 1

      parsed_uri = URI(uri)

      http = Net::HTTP.new parsed_uri.host, parsed_uri.port
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 10
      http.write_timeout = 10
      http.ssl_timeout = 10

      request = Net::HTTP::Get.new parsed_uri
      headers.each do |key, value|
        request[key] = value
      end

      response = http.request request

      JSON.parse response.body
    rescue Net::OpenTimeout
      retry if attempt < 4
    end
  end
end
