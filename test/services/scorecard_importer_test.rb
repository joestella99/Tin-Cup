require "test_helper"

class ScorecardImporterTest < ActiveSupport::TestCase
  test "plain-text gross scorecards" do
    assert_equal [3] * 18, ScorecardImporter.parse(([3] * 18).join(", "))
    assert_equal [4] * 18, ScorecardImporter.parse(([4] * 18).join("\n"))
  end

  test "reads hole and strokes csv in any row order" do
    rows = (1..18).to_a.reverse.map { |n| "#{n},#{(n % 4) + 3}" }
    scores = ScorecardImporter.parse("hole,strokes\n" + rows.join("\n"))
    assert_equal 18, scores.length
    assert_equal 4, scores.first
    assert_equal 5, scores.second
  end

  test "rejects missing repeated invalid and extra data" do
    bad = [ "1,2,3", ([4] * 17 + [0]).join(","), ([4] * 17 + [31]).join(","),
      ([4] * 19).join(","), "hole,strokes\n" + (1..18).map { "1,4" }.join("\n"),
      "hole,strokes\n" + (1..17).map { |n| "#{n},4" }.join("\n"),
      "<script>alert(1)</script>" ]
    bad.each { |raw| assert_raises(ScorecardImporter::Invalid) { ScorecardImporter.parse(raw) } }
  end
end
