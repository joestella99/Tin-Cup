# Cached community course metadata and hole data; rounds snapshot this at creation.
class GolfCourse < ApplicationRecord
  has_many :rounds, dependent: :nullify
  validates :name, :external_id, presence: true
  validates :external_id, uniqueness: true

  def location
    [ city, state, country ].reject(&:blank?).join(", ")
  end

  def display_name
    [ name, location.presence ].compact.join(" · ")
  end

  def tee_names
    Array(tee_options).filter_map do |tee|
      next unless tee.is_a?(Hash)
      (tee["tee_name"] || tee["name"] || tee["color"] || tee["label"]).to_s.strip.presence
    end.uniq
  end

  def tee_details(name)
    return nil if name.blank?
    Array(tee_options).find do |tee|
      tee.is_a?(Hash) && [ tee["tee_name"], tee["name"], tee["color"], tee["label"] ].compact.any? { |value| value.to_s.casecmp?(name.to_s) }
    end
  end

  def display_scorecard_entries
    by_number = Array(scorecard).filter_map do |data|
      next unless data.is_a?(Hash)
      n = Integer(data["number"], exception: false)
      next unless n && (1..18).cover?(n)
      [ n, data ]
    end.to_h
    (1..18).map do |number|
      data = by_number[number] || {}
      par = Integer(data["par"], exception: false)
      index = Integer(data["stroke_index"], exception: false)
      { number: number, par: par && (3..6).cover?(par) ? par : nil,
        stroke_index: index && (1..18).cover?(index) ? index : nil,
        yardages: data["yardages"].is_a?(Hash) ? data["yardages"] : {} }
    end
  end

  # The absence of a valid handicap index means no automatic confirmation,
  # even if we have some useful pars and distances.
  def scorecard_entries
    entries = display_scorecard_entries
    return [] unless entries.all? { |h| h[:par] && h[:stroke_index] }
    return [] unless entries.map { |h| h[:stroke_index] }.sort == (1..18).to_a
    entries
  end

  def complete_scorecard?
    scorecard_entries.size == 18
  end

  def available_holes
    display_scorecard_entries.count { |h| h[:par] }
  end

  def yardage_for(hole, tee_name)
    return nil if tee_name.blank?
    yardages = hole[:yardages]
    return nil unless yardages.is_a?(Hash)
    value = yardages.find { |name, _| name.to_s.casecmp?(tee_name.to_s) }&.last
    value = value["yards"] || value["yardage"] if value.is_a?(Hash)
    yards = Integer(value, exception: false)
    yards if yards && (20..800).cover?(yards)
  end

  def self.import!(raw)
    raise ArgumentError, "Invalid course data" unless raw.is_a?(Hash)
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
      tee_options: Array(raw["tee_options"]).select { |tee| tee.is_a?(Hash) }.first(25),
      scorecard: Array(raw["scorecard"]).filter_map do |hole|
        next unless hole.is_a?(Hash)
        number = Integer(hole["hole_number"] || hole["number"] || hole["hole"], exception: false)
        next unless number && (1..18).cover?(number)
        par = Integer(hole["par"], exception: false)
        index = Integer(hole["handicap_index"] || hole["stroke_index"], exception: false)
        yardages = hole["yardages"].is_a?(Hash) ? hole["yardages"] : {}
        { "number" => number, "par" => par, "stroke_index" => index, "yardages" => yardages }
      end
    }
    record = find_or_initialize_by(external_id: raw.fetch("id").to_s)
    # Don't regress an existing full card if an upstream refresh is incomplete.
    if record.persisted?
      previous = Array(record.scorecard).index_by { |hole| hole["number"] }
      updated = attrs[:scorecard].index_by { |hole| hole["number"] }
      attrs[:scorecard] = (1..18).filter_map do |number|
        prior = previous[number]
        newer = updated[number]
        next prior unless newer
        if prior
          newer["par"] ||= prior["par"]
          newer["stroke_index"] ||= prior["stroke_index"]
          newer["yardages"] = (prior["yardages"].is_a?(Hash) ? prior["yardages"] : {}).merge(newer["yardages"])
        end
        newer
      end
      attrs[:tee_options] = record.tee_options if attrs[:tee_options].empty?
    end
    record.update!(attrs)
    record
  end
end
