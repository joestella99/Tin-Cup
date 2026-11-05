require "net/http"
require "json"
require "uri"
require "digest"

# OpenGolfAPI data remains server-side; only fixed HTTPS endpoints are queried.
class OpenGolfApi
  class Unavailable < StandardError; end
  HOST = "api.opengolfapi.org"
  ID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  def self.search(term)
    q = term.to_s.strip[0, 80]
    return [] if q.length < 2
    Rails.cache.fetch("open_golf/search/v1/#{Digest::SHA256.hexdigest(q.downcase)}", expires_in: 6.hours) do
      response = get("/v1/courses/search", q: q, limit: 25)
      Array(response.fetch("courses", [])).select { |item| item.is_a?(Hash) && item["id"].present? && item["course_name"].present? }
    end
  end

  def self.course(id)
    validate_id!(id)
    Rails.cache.fetch("open_golf/course/v1/#{id}", expires_in: 24.hours) do
      response = get("/v1/courses/#{id}")
      raise Unavailable, "This course could not be loaded" unless response.is_a?(Hash) && response["course_name"].present?
      response
    end
  end

  def self.holes(id)
    validate_id!(id)
    Rails.cache.fetch("open_golf/holes/v1/#{id}", expires_in: 24.hours) do
      result = get("/v1/courses/#{id}/holes")
      Array(result.is_a?(Hash) ? result["holes"] : []).select { |item| item.is_a?(Hash) }
    end
  end

  def self.tees(id)
    validate_id!(id)
    Rails.cache.fetch("open_golf/tees/v1/#{id}", expires_in: 24.hours) do
      result = get("/v1/courses/#{id}/tees")
      Array(result.is_a?(Hash) ? result["tees"] : []).select { |item| item.is_a?(Hash) }
    end
  end

  # Course detail, hole yardages and tee sets are separate upstream resources.
  # An auxiliary endpoint outage doesn't throw away an otherwise useful scorecard.
  def self.full_course(id)
    raw = course(id).dup
    begin
      extended_holes = holes(id)
      raw["scorecard"] = merge_holes(Array(raw["scorecard"]), extended_holes) if extended_holes.any?
    rescue Unavailable
      # Preserve the base card when optional geometry is unavailable.
    end
    begin
      raw["tee_options"] = tees(id)
    rescue Unavailable
      raw["tee_options"] = []
    end
    raw
  end

  def self.merge_holes(basic, extended)
    by_number = {}
    (basic + extended).each do |hole|
      next unless hole.is_a?(Hash)
      number = Integer(hole["hole_number"] || hole["number"] || hole["hole"], exception: false)
      next unless number && (1..18).cover?(number)
      by_number[number] = by_number.fetch(number, {}).merge(hole.compact)
      by_number[number]["hole_number"] = number
    end
    by_number.sort.map(&:last)
  end
  private_class_method :merge_holes

  def self.validate_id!(id)
    raise ArgumentError, "Invalid course identifier" unless id.to_s.match?(ID_PATTERN)
  end
  private_class_method :validate_id!

  def self.get(path, params = {})
    uri = URI::HTTPS.build(host: HOST, path: path, query: params.any? ? URI.encode_www_form(params) : nil)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 5) do |http|
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/json"
      request["User-Agent"] = "TinCupGolf/1.1 (golf trip tournament organizer)"
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
