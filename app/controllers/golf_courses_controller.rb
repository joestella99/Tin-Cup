class GolfCoursesController < ApplicationController
  before_action :load_trip

  def index
    @query = params[:q].to_s.strip[0, 80]
    @saved = if @query.present?
      GolfCourse.where("name ILIKE :q OR city ILIKE :q OR state ILIKE :q", q: "%#{GolfCourse.sanitize_sql_like(@query)}%").order(:name).limit(30)
    else
      GolfCourse.order(updated_at: :desc).limit(18)
    end
    @found = []
    if @query.length >= 2
      begin
        @found = OpenGolfApi.search(@query)
      rescue OpenGolfApi::Unavailable
        @directory_unavailable = true
      end
    end
    @saved_ids = GolfCourse.where(external_id: @found.map { |item| item["id"].to_s }).pluck(:external_id).to_set
  end

  def show
    @course = GolfCourse.find(params[:id])
  end

  def create
    raise ActiveRecord::RecordNotFound unless organizer_for?(@trip)
    external_id = params.require(:external_id).to_s
    course = GolfCourse.find_by(external_id: external_id)
    course ||= GolfCourse.import!(OpenGolfApi.course(external_id))
    redirect_to trip_path(@trip, selected_course_id: course.id, anchor: "schedule-round"),
      notice: "#{course.name} added to the course library. Choose your date to schedule it."
  rescue OpenGolfApi::Unavailable, ArgumentError, KeyError, ActiveRecord::RecordInvalid => error
    redirect_to trip_golf_courses_path(@trip, q: params[:q]),
      alert: "We couldn't save that course: #{error.message}"
  end

  private

  def load_trip
    @trip = find_trip!
  end
end
