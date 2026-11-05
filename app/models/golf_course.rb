# Cached, attributable community course data. Rounds take an immutable snapshot
# of the imported scorecard, so later API corrections never rewrite live results.
class GolfCourse < ApplicationRecord
  has_many :rounds, dependent: :nullify
  validates :name, :external_id, presence: true
  validates :external_id, uniqueness: true

  def location
    [city, state, country].reject(&:blank?).join(", ")
  end

  def display_name
    [name, location.presence].compact.join(" · ")
  end

  def scorecard_entries
    normalized = Array(scorecard).filter_map do |data|
      next unless data.is_a?(Hash)
      number = Integer(data["number"], exception: false)
      par = Integer(data["par"], exception: false)
      index = Integer(data["stroke_index"], exception: false)
      next unless number && (1..18).cover?(number) && par && (3..6).cover?(par) && index && (1..18).cover?(index)
      { number: number, par: par, stroke_index: index }
    end
    return [] unless normalized.size == 18
    return [] unless normalized.map { |h| h[:number] }.sort == (1..18).to_a
    return [] unless normalized.map { |h| h[:stroke_index] }.sort == (1..18).to_a

    normalized.sort_by { |hole| hole[:number] }
  end

  def complete_scorecard?
    scorecard_entries.size == 18
  end

  def self.import!(raw)
    attrs = {
      name: raw.fetch("course_name").to_s.strip,
      city: raw["city"].to_s.presence,
      state: raw["state"].to_s.presence,
      country: raw["country"].to_s.presence,
      address: raw["address"].to_s.presence,
      course_type: raw["course_type"].to_s.presence,
      website: raw["website"].to_s.presence,
      holes_count: Integer(raw["holes"], exception: false),
      par_total: Integer(raw["par_total"], exception: false),
      scorecard: Array(raw["scorecard"]).filter_map do |hole|
        next unless hole.is_a?(Hash)
        number = Integer(hole["hole_number"], exception: false)
        par = Integer(hole["par"], exception: false)
        index = Integer(hole["handicap_index"], exception: false)
        next unless number && par && index
        { "number" => number, "par" => par, "stroke_index" => index }
      end
    }
    record = find_or_initialize_by(external_id: raw.fetch("id").to_s)
    record.update!(attrs)
    record
  end
end
