ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
class ActiveSupport::TestCase
  parallelize(workers: 1)
  def build_trip(name: "Annual Cup")
    Trip.create!(name: name, destination: "Pinehurst", starts_on: Date.new(2027, 5, 1), ends_on: Date.new(2027, 5, 3))
  end
end
