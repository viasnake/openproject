# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

class MeetingsController < ApplicationController
  before_action :load_and_authorize_in_optional_project

  before_action :determine_date_range, only: %i[history]
  before_action :determine_author, only: %i[history]
  before_action :build_meeting, only: %i[new new_dialog fetch_timezone]
  before_action :find_meeting, except: %i[index new create new_dialog fetch_timezone]
  before_action :redirect_to_project, only: %i[show]
  before_action :set_activity, only: %i[history]
  before_action :find_copy_from_meeting, only: %i[create]
  before_action :convert_params, only: %i[create update update_participants]
  before_action :prevent_template_destruction, only: :destroy

  helper :watchers
  include MeetingsHelper
  include Layout
  include WatchersHelper
  include PaginationHelper
  include SortHelper

  include OpTurbo::ComponentStream
  include OpTurbo::FlashStreamHelper
  include OpTurbo::DialogStreamHelper
  include Meetings::AgendaComponentStreams
  include MetaTagsHelper

  menu_item :new_meeting, only: %i[new create]

  def index
    load_meetings

    render "index",
           locals: { menu_name: project_or_global_menu }
  end

  current_menu_item :index do
    :meetings
  end

  def show
    respond_to do |format|
      format.html do
        html_title "#{t(:label_meeting)}: #{@meeting.title}"
        if @meeting.state == "cancelled"
          render_404
        else
          render(Meetings::ShowComponent.new(meeting: @meeting), layout: true)
        end
      end
    end
  end

  def check_for_updates
    if params[:reference] == @meeting.changed_hash
      head :no_content
    else
      respond_with_flash(Meetings::UpdateFlashComponent.new(@meeting))
    end
  end

  def create # rubocop:disable Metrics/AbcSize
    call =
      if @copy_from
        ::Meetings::CopyService
          .new(user: current_user, model: @copy_from)
          .call(attributes: @converted_params, **copy_attributes)
      else
        ::Meetings::CreateService
          .new(user: current_user)
          .call(@converted_params)
      end

    @meeting = call.result

    if call.success?
      text = I18n.t(:notice_successful_create)
      unless User.current.pref.time_zone?
        link = I18n.t(:notice_timezone_missing, zone: formatted_time_zone_offset)
        text += " #{view_context.link_to(link, { controller: '/my', action: :settings, anchor: 'pref_time_zone' },
                                         class: 'link_to_profile')}"
      end
      flash[:notice] = text.html_safe # rubocop:disable Rails/OutputSafety

      redirect_to status: :see_other, action: "show", id: @meeting
    else
      respond_to do |format|
        format.html do
          render action: :new,
                 status: :unprocessable_entity,
                 project_id: @project,
                 locals: { copy_from: @copy_from }
        end

        format.turbo_stream do
          update_via_turbo_stream(
            component: Meetings::Index::FormComponent.new(
              meeting: @meeting,
              project: @project,
              copy_from: @copy_from
            ),
            status: :bad_request
          )

          respond_with_turbo_streams
        end
      end
    end
  end

  def new_dialog
    respond_with_dialog Meetings::Index::DialogComponent.new(
      meeting: @meeting,
      project: @project
    )
  end

  def new; end

  current_menu_item :new do
    :meetings
  end

  def copy
    copy_from = @meeting
    call = ::Meetings::CopyService
      .new(user: current_user, model: copy_from)
      .call(save: false)

    @meeting = call.result
    respond_to do |format|
      format.html do
        render action: :new, status: :unprocessable_entity, project_id: @project, locals: { copy_from: }
      end

      format.turbo_stream do
        respond_with_dialog Meetings::Index::DialogComponent.new(
          meeting: @meeting,
          project: @project,
          copy_from:
        )
      end
    end
  end

  def delete_dialog
    respond_with_dialog Meetings::DeleteDialogComponent.new(
      meeting: @meeting,
      back_url: params[:back_url]
    )
  end

  def destroy # rubocop:disable Metrics/AbcSize
    recurring = @meeting.recurring_meeting

    # rubocop:disable Rails/ActionControllerFlashBeforeRender
    Meetings::DeleteService
      .new(model: @meeting, user: User.current)
      .call
      .on_success { flash[:notice] = recurring ? I18n.t(:notice_successful_cancel) : I18n.t(:notice_successful_delete) }
      .on_failure { |call| flash[:error] = call.message }
    # rubocop:enable Rails/ActionControllerFlashBeforeRender

    if recurring
      redirect_to project_recurring_meeting_path(@project, recurring), status: :see_other
    else
      redirect_back_or_default project_meetings_path(@project), status: :see_other
    end
  end

  def edit
    respond_to do |format|
      format.turbo_stream do
        update_header_component_via_turbo_stream(state: :edit)

        render turbo_stream: @turbo_streams
      end
      format.html do
        render :edit
      end
    end
  end

  def history
    @events = get_events
  rescue ActiveRecord::RecordNotFound => e
    op_handle_warning "Failed to find all resources in activities: #{e.message}"
    render_404 I18n.t(:error_can_not_find_all_resources)
  end

  def cancel_edit
    update_header_component_via_turbo_stream(state: :show)

    respond_with_turbo_streams
  end

  def update
    call = ::Meetings::UpdateService
      .new(user: current_user, model: @meeting)
      .call(@converted_params)

    if call.success?
      flash[:notice] = I18n.t(:notice_successful_update)
      redirect_to action: "show", id: @meeting
    else
      @meeting = call.result
      render action: :edit, status: :unprocessable_entity
    end
  end

  def details_dialog; end

  def participants_dialog; end

  def update_participants
    @meeting.participants_attributes = @converted_params.delete(:participants_attributes)
    @meeting.save

    update_sidebar_details_component_via_turbo_stream
    update_sidebar_participants_component_via_turbo_stream

    respond_with_turbo_streams
  end

  def update_title
    @meeting.update(title: meeting_params[:title])

    if @meeting.errors.any?
      update_header_component_via_turbo_stream(state: :edit)
    else
      update_header_component_via_turbo_stream(state: :show)
    end

    respond_with_turbo_streams
  end

  def update_details
    call = ::Meetings::UpdateService
      .new(user: current_user, model: @meeting)
      .call(meeting_params)

    if call.success?
      update_header_component_via_turbo_stream
      update_sidebar_details_component_via_turbo_stream

      # the list needs to be updated if the start time has changed
      # in order to update the agenda item time slots
      update_list_via_turbo_stream if @meeting.previous_changes[:start_time].present?
    else
      update_sidebar_details_form_component_via_turbo_stream
    end

    respond_with_turbo_streams
  end

  def change_state
    case params[:state]
    when "open"
      @meeting.open!
    when "closed"
      @meeting.closed!
    when "in_progress"
      @meeting.in_progress!
    end

    if @meeting.errors.any?
      update_sidebar_state_component_via_turbo_stream
    else
      update_all_via_turbo_stream
      update_backlog_via_turbo_stream(collapsed: nil)
    end

    respond_with_turbo_streams
  end

  def download_ics
    ::Meetings::ICalService
      .new(user: current_user, meeting: @meeting)
      .call
      .on_failure { |call| render_500(message: call.message) }
      .on_success do |call|
      send_data call.result, filename: filename_for_content_disposition("#{@meeting.title}.ics")
    end
  end

  def notify
    service = MeetingNotificationService.new(@meeting)
    result = service.call(:invited)

    if result.success?
      flash[:notice] = I18n.t(:notice_successful_notification)
    else
      flash[:error] = I18n.t(:error_notification_with_errors,
                             recipients: result.errors.map(&:name).join("; "))
    end

    redirect_to action: :show, id: @meeting
  end

  def fetch_timezone
    return unless timezone_params.keys.count == 2

    User.execute_as(User.current) do
      meeting = Meeting.new(timezone_params)
      @text = friendly_timezone_name(User.current.time_zone, period: meeting.start_time)
    end

    add_caption_to_input_element_via_turbo_stream("input[name='meeting[start_time_hour]']",
                                                  caption: @text,
                                                  clean_other_captions: true)

    respond_with_turbo_streams
  end

  private

  def load_query
    query = ParamsToQueryService.new(
      Meeting,
      current_user
    ).call(params)

    apply_default_filter_if_none_given(query)
    apply_time_filter_and_sort(query)
    query.where("project_id", "=", @project.id) if @project

    query
  end

  def apply_time_filter_and_sort(query)
    if params[:upcoming] == "false"
      query.where("time", "=", Queries::Meetings::Filters::TimeFilter::PAST_VALUE)
      query.order(start_time: :desc)
    else
      query.where("time", "=", Queries::Meetings::Filters::TimeFilter::FUTURE_VALUE)
      query.order(start_time: :asc)
    end
  end

  def apply_default_filter_if_none_given(query)
    return if params.key?(:filters)

    query.where("invited_user_id", "=", [User.current.id.to_s])
  end

  def load_meetings
    @query = load_query

    # We group meetings into individual groups, but only for upcoming meetings
    if params[:upcoming] == "false"
      @meetings = show_more_pagination(@query.results)
    else
      @grouped_meetings = group_meetings(@query.results)
    end
  end

  def group_meetings(all_meetings) # rubocop:disable Metrics/AbcSize
    next_week = Time
      .current
      .next_occurring(OpenProject::Internationalization::Date.beginning_of_week)
      .beginning_of_day
    groups = Hash.new { |h, k| h[k] = [] }
    groups[:later] = show_more_pagination(all_meetings
                                            .where(start_time: next_week..)
                                            .order(start_time: :asc))

    all_meetings
      .where(start_time: ...next_week)
      .order(start_time: :asc)
      .each do |meeting|
      start_date = meeting.start_time.to_date

      group_key =
        if start_date == Time.zone.today
          :today
        elsif start_date == Time.zone.tomorrow
          :tomorrow
        else
          :this_week
        end

      groups[group_key] << meeting
    end

    groups
  end

  def build_meeting
    meeting =
      if params[:type] == "recurring"
        RecurringMeeting.new
      else
        Meeting.new
      end

    service = meeting.is_a?(RecurringMeeting) ? ::RecurringMeetings::SetAttributesService : ::Meetings::SetAttributesService
    call = service
      .new(user: current_user, model: meeting, contract_class: EmptyContract)
      .call(project: @project)

    @meeting = call.result
  end

  def global_upcoming_meetings
    projects = Project.allowed_in_project(User.current, :view_meetings)

    Meeting.where(project: projects).from_today
  end

  def find_meeting
    @meeting = Meeting
      .includes([:project, :author, { participants: :user }, :sections, { agenda_items: :outcomes }])
      .find(params[:id])
  end

  def convert_params # rubocop:disable Metrics/AbcSize
    # We do some preprocessing of `meeting_params` that we will store in this
    # instance variable.
    @converted_params = meeting_params.to_h

    @converted_params[:project] = @project if @project.present?
    @converted_params[:duration] = @converted_params[:duration].to_hours if @converted_params[:duration].present?
    @converted_params[:send_notifications] = params[:send_notifications] == "1"

    # Handle participants separately for each meeting type
    @converted_params[:participants_attributes] ||= {}
    if copy_meeting_participants?
      create_participants
    else
      force_defaults
    end

    # Recurring meeting occurrences can only be copied as one-time meetings
    @converted_params[:recurring_meeting_id] = nil
  end

  def meeting_params
    if params[:meeting].present?
      params
        .require(:meeting)
        .permit(:title, :location, :start_time, :project_id,
                :duration, :start_date, :start_time_hour,
                participants_attributes: %i[email name invited attended user user_id meeting id])
    end
  end

  def set_activity
    @activity = Activities::Fetcher.new(User.current,
                                        project: @project,
                                        with_subprojects: @with_subprojects,
                                        author: @author,
                                        scope: activity_scope,
                                        meeting: @meeting)
  end

  def get_events
    Activities::MeetingEventMapper
      .new(@meeting)
      .map_to_events
  end

  def activity_scope
    ["meetings", "meeting_agenda_items"]
  end

  def determine_date_range
    @days = Setting.activity_days_default.to_i

    if params[:from]
      begin
        @date_to = params[:from].to_date + 1.day
      rescue StandardError
      end
    end

    @date_to ||= User.current.today + 1.day
    @date_from = @date_to - @days
  end

  def determine_author
    @author = params[:user_id].blank? ? nil : User.active.find(params[:user_id])
  end

  def find_copy_from_meeting
    copied_from_meeting_id = params[:copied_from_meeting_id] || params[:meeting][:copied_from_meeting_id]
    return unless copied_from_meeting_id

    @copy_from = Meeting.visible.find(copied_from_meeting_id)
  end

  def copy_attributes
    {
      copy_agenda: copy_param(:copy_agenda),
      copy_attachments: copy_param(:copy_attachments),
      send_notifications: copy_param(:send_notifications)
    }
  end

  def prevent_template_destruction
    render_400 if @meeting.templated?
  end

  def redirect_to_project
    return if @project

    redirect_to project_meeting_path(@meeting.project, @meeting, tab: params[:tab]), status: :see_other
  end

  def timezone_params
    @timezone_params ||= params.require(:meeting).permit(:start_date, :start_time_hour).compact_blank
  end
end
