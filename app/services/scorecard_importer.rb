require "csv"

# Single-player gross stroke importer. No external credentials or invented scores.
# Authorized provider adapters can later output the same validated 18 values.
class ScorecardImporter
  class Invalid < StandardError; end

  def self.parse(text)
    raw = text.to_s.strip
    raise Invalid, "Enter 18 scores or upload a CSV/TXT file." if raw.blank?
    raise Invalid, "Scorecard is too large (32 KB maximum)." if raw.bytesize > 32_768

    simple = raw.split(/[\s,;|]+/)
    return validate!(simple) if simple.size == 18 && simple.all? { |v| v.match?(/\A\d+\z/) }

    rows = CSV.parse(raw)
    raise Invalid, "The scorecard must contain 18 hole scores." if rows.empty?
    headers = rows.first.map { |part| part.to_s.strip.downcase.gsub(/[^a-z0-9]/, "") }
    hole_col = headers.index { |name| %w[hole holenumber number].include?(name) }
    score_col = headers.index { |name| %w[strokes score gross grossscore].include?(name) }

    if hole_col && score_col
      by_hole = {}
      rows.drop(1).each do |row|
        next if row.compact.all?(&:blank?)
        number = Integer(row[hole_col], exception: false)
        strokes = Integer(row[score_col], exception: false)
        raise Invalid, "Use holes 1–18 and stroke totals 1–30." unless number && (1..18).cover?(number) && strokes && (1..30).cover?(strokes)
        raise Invalid, "Hole #{number} appears more than once." if by_hole.key?(number)
        by_hole[number] = strokes
      end
      raise Invalid, "Each hole from 1 to 18 needs one score." unless by_hole.keys.sort == (1..18).to_a
      return (1..18).map { |n| by_hole.fetch(n) }
    end

    if rows.size == 2 && rows.first.map(&:to_s).map(&:strip) == (1..18).map(&:to_s)
      return validate!(rows.last)
    end
    return validate!(rows.first) if rows.size == 1 && rows.first.size == 18
    return validate!(rows.map(&:first)) if rows.size == 18 && rows.all? { |row| row.size == 1 }

    raise Invalid, "Use 18 gross scores in hole order, or CSV columns named hole and strokes. Screenshots and private app links are not supported yet."
  rescue CSV::MalformedCSVError
    raise Invalid, "That isn't valid CSV. Try 18 numbers separated by spaces or commas."
  end

  def self.validate!(values)
    raise Invalid, "Exactly 18 scores are required." unless values.size == 18
    scores = values.map { |v| Integer(v.to_s.strip, exception: false) }
    raise Invalid, "Every hole needs a gross score between 1 and 30 strokes." unless scores.all? { |v| v && (1..30).cover?(v) }
    scores
  end
  private_class_method :validate!
end
