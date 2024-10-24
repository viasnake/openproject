# frozen_string_literal: true

class WorkPackages::HighlightedDateComponent < ApplicationComponent
  include OpPrimer::ComponentHelpers

  def initialize(work_package:, text_arguments: {})
    super

    @work_package = work_package
    @start_date = work_package.start_date
    @due_date = work_package.due_date

    @text_arguments = text_arguments
  end

  def parsed_date(date)
    return if date.nil?

    date.strftime(I18n.t("date.formats.default"))
  end

  def date_classes(date)
    return if date.nil?

    diff = (date - Time.zone.today).to_i
    if diff === 0
      return "__hl_date_due_today"
    elsif diff <= -1
      return "__hl_date_overdue"
    end

    "__hl_date_not_overdue"
  end
end
