require "net/http"
require "json"
require "uri"

# Strictly server-side OpenGolfAPI client, with bounded timeouts and caching.
# No user-controlled URLs or arbitrary remote endpoints are accepted.
class OpenGolfApi
  class Unavailable < StandardError; end
  HOST = "api.opengolfapi.org"
  ID_PATTERN = /\\A[0-9a-f-]{36}\\z/i

  def self.search(term)
    q = term.to_s.strip[0, 80]
    return [] if q.length < 2
    Rails.cache.fetch("open_golf/search/v1/#{Digest::SHA256.hexdigest(q.downcase)}", expires_in: 6.hours) do
      response = get("/v1/courses/search", q: q, limit: 25)
      Array(response.fetch("courses", [])).select { |item| item.is_a?(Hash) && item["id"].present? && item["course_name"].present? }
    end
  end

  def self.course(id)
    raise ArgumentError, "Invalid course identifier" unless id.to_s.match?(ID_PATTERN)

    Rails.cache.fetch("open_golf/course/v1/#{id}", expires_in: 24.hours) do
      response = get("/v1/courses/#{id}")
      raise Unavailable, "This course could not be loaded" unless response.is_a?(Hash) && response["course_name"].present?
      response
    end
  end

  def self.get(path, params = {})
    uri = URI::HTTPS.build(host: HOST, path: path, query: params.any? ? URI.encode_www_form(params) : nil)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 5) do |http|
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/json"
      request["User-Agent"] = "TinCupGolf/1.0 (golf trip tournament organizer)"
      request["Authorization"] = "Bearer #{ENV.fetch('OPEN_GOLF_API_KEY')}" if ENV["OPEN_GOLF_API_KEY"].present?
      http.request(request)
    end
    raise Unavailable, "The course directory is temporarily unavailable" unless response.is_a?(Net::HTTPSuccess)
    raise Unavailable, "The course response was too large" if response.body.to_s.bytesize > 1_000_000
    JSON.parse(response.body)
  rescue IOError, SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, JSON::ParserError => e
    raise Unavailable, "The course directory is temporarily unavailable (#{e.class.name})"
  end
  private_class_method :get
end
