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

class MeetingAgendaItemsController < ApplicationController
  include AttachableServiceCall
  include OpTurbo::ComponentStream
  include OpTurbo::FlashStreamHelper
  include Meetings::AgendaComponentStreams

  before_action :set_meeting
  before_action :set_agenda_item_type, only: %i[new create]
  before_action :set_meeting_agenda_item,
                except: %i[new cancel_new create]
  before_action :authorize
  before_action :check_recurring_meeting_param, only: %i[move_to_next_meeting]
  before_action :assign_drop_params, only: %i[drop]

  def new
    if @meeting.closed?
      update_all_via_turbo_stream
      render_error_flash_message_via_turbo_stream(message: t("text_meeting_not_editable_anymore"))
    else
      if params[:meeting_section_id].present?
        meeting_section = MeetingSection.find_by(id: params[:meeting_section_id])
        if meeting_section.backlog?
          collapsed = false
        end
      end
      render_agenda_item_form_via_turbo_stream(meeting_section:, collapsed:, type: @agenda_item_type)
    end

    respond_with_turbo_streams
  end

  def cancel_new
    if params[:meeting_section_id].present?
      meeting_section = MeetingSection.find_by(id: params[:meeting_section_id])
      if meeting_section.agenda_items.empty?
        if meeting_section.backlog?
          collapsed = false
        end
        update_section_via_turbo_stream(form_hidden: true, meeting_section:, collapsed:)
      else
        update_new_button_via_turbo_stream(disabled: false, meeting_section:)
      end
    end

    update_new_component_via_turbo_stream(hidden: true, meeting_section:)
    update_new_button_via_turbo_stream(disabled: false)

    respond_with_turbo_streams
  end

  def create # rubocop:disable Metrics/AbcSize
    call = ::MeetingAgendaItems::CreateService
      .new(user: current_user)
      .call(
        meeting_agenda_item_params.merge(
          meeting_id: @meeting.id,
          item_type: @agenda_item_type.presence || MeetingAgendaItem::ITEM_TYPES[:simple]
        )
      )

    @meeting_agenda_item = call.result

    if call.success?
      reset_meeting_from_agenda_item
      # enable continue editing
      update_header_component_via_turbo_stream
      update_sidebar_details_component_via_turbo_stream
      if @meeting_agenda_item.meeting_section.backlog?
        update_section_via_turbo_stream(meeting_section: @meeting_agenda_item.meeting_section, collapsed: false)
        update_new_button_via_turbo_stream(disabled: false)
      else
        add_item_via_turbo_stream(clear_slate: false)
      end
    else
      # show errors
      update_new_component_via_turbo_stream(
        hidden: false, meeting_agenda_item: @meeting_agenda_item, type: @agenda_item_type
      )
      render_base_error_in_flash_message_via_turbo_stream(call.errors)
    end

    respond_with_turbo_streams
  end

  def edit
    if @meeting_agenda_item.editable?
      update_item_via_turbo_stream(state: :edit, display_notes_input: params[:display_notes_input])
    else
      update_all_via_turbo_stream
      render_error_flash_message_via_turbo_stream(message: t("text_meeting_not_editable_anymore"))
    end

    respond_with_turbo_streams
  end

  def cancel_edit
    update_item_via_turbo_stream(state: :show)

    respond_with_turbo_streams
  end

  def update
    call = ::MeetingAgendaItems::UpdateService
      .new(user: current_user, model: @meeting_agenda_item)
      .call(meeting_agenda_item_params)

    if call.success?
      reset_meeting_from_agenda_item
      update_item_via_turbo_stream
      update_section_header_via_turbo_stream(meeting_section: @meeting_agenda_item.meeting_section)
      update_header_component_via_turbo_stream
      update_sidebar_details_component_via_turbo_stream
    else
      # show errors
      update_item_via_turbo_stream(state: :edit)
      render_base_error_in_flash_message_via_turbo_stream(call.errors)
    end

    respond_with_turbo_streams
  end

  def destroy # rubocop:disable Metrics/AbcSize
    section = @meeting_agenda_item.meeting_section

    call = ::MeetingAgendaItems::DeleteService
      .new(user: current_user, model: @meeting_agenda_item)
      .call

    if call.success?
      reset_meeting_from_agenda_item
      update_header_component_via_turbo_stream
      update_sidebar_details_component_via_turbo_stream
      if section.backlog?
        update_section_via_turbo_stream(meeting_section: section, collapsed: false)
      else
        remove_item_via_turbo_stream(clear_slate: @meeting.agenda_items.empty?)
        update_section_header_via_turbo_stream(meeting_section: section) if section&.reload.present?
      end
    else
      generic_call_failure_response(call)
    end

    respond_with_turbo_streams
  end

  def drop # rubocop:disable Metrics/AbcSize
    meeting_agenda_item_section = @meeting_agenda_item.meeting_section

    call = if @target_id.nil?
             ::MeetingAgendaItems::UpdateService
               .new(user: current_user, model: @meeting_agenda_item)
               .call(meeting_id: params[:current_meeting_id], meeting_section: nil)
           else
             ::MeetingAgendaItems::DropService
               .new(user: current_user, meeting_agenda_item: @meeting_agenda_item)
               .call(target_id: @target_id, position: @position)
           end

    if call.success?
      old_section, current_section, section_changed = assign_drop_results(call, meeting_agenda_item_section)

      if section_changed
        move_item_to_other_section_via_turbo_stream(
          old_section:,
          current_section:,
          collapsed: ActiveModel::Type::Boolean.new.cast(params[:collapsed])
        )
      else
        move_item_within_section_via_turbo_stream
      end
    else
      generic_call_failure_response(call)
    end

    respond_with_turbo_streams
  end

  def move
    call = ::MeetingAgendaItems::UpdateService
      .new(user: current_user, model: @meeting_agenda_item)
      .call(move_to: params[:move_to]&.to_sym)

    if call.success?
      move_item_within_section_via_turbo_stream
    else
      generic_call_failure_response(call)
    end

    respond_with_turbo_streams
  end

  def move_to_next_meeting # rubocop:disable Metrics/AbcSize
    next_occurrence = init_next_meeting_occurrence
    return if next_occurrence.nil?

    update_call = ::MeetingAgendaItems::UpdateService
      .new(user: current_user, model: @meeting_agenda_item)
      .call(meeting_id: next_occurrence.id, meeting_section: nil)

    if update_call.success?
      render_success_flash_message_via_turbo_stream(
        message: I18n.t(:text_agenda_item_moved_to_next_meeting, date: format_date(next_occurrence.start_time))
      )
      remove_item_via_turbo_stream(clear_slate: @meeting.agenda_items.empty?)
      update_header_component_via_turbo_stream
      respond_with_turbo_streams
    else
      respond_with_flash_error(message: call.message)
    end
  end

  private

  def init_next_meeting_occurrence
    return @next_occurrence if @next_occurrence.present?

    call = ::RecurringMeetings::InitOccurrenceService
    .new(user: User.system, recurring_meeting: @series)
    .call(start_time: @next_meeting_time)

    if call.success?
      call.result
    else
      respond_with_flash_error(message: call.message)
      nil
    end
  end

  def set_meeting
    @meeting = Meeting.find(params[:meeting_id])
    @project = @meeting.project # required for authorization via before_action
  end

  # In case we updated the meeting as part of the service flow
  # it needs to be reassigned for the controller in order to get correct timestamps
  def reset_meeting_from_agenda_item
    @meeting = @meeting_agenda_item.meeting
  end

  def set_agenda_item_type
    @agenda_item_type = params[:type]&.to_sym
  end

  def set_meeting_agenda_item
    @meeting_agenda_item = MeetingAgendaItem.find(params[:id])
  end

  def meeting_agenda_item_params
    params
      .require(:meeting_agenda_item)
      .permit(:title, :duration_in_minutes, :presenter_id, :notes, :work_package_id, :lock_version, :meeting_section_id)
  end

  def generic_call_failure_response(call)
    # A failure might imply that the meeting was already closed and the action was triggered from a stale browser window
    # updating all components resolves the stale state of that window
    update_all_via_turbo_stream
    # show additional base error message
    render_base_error_in_flash_message_via_turbo_stream(call.errors)
  end

  def check_recurring_meeting_param
    if @meeting.closed? || !@meeting.recurring?
      return render_400
    end

    @next_meeting_time = DateTime.iso8601(params[:datetime]).utc
    @series = @meeting.recurring_meeting

    render_400 unless @next_meeting_time && @series.occurs_at?(@next_meeting_time)
    find_existing_occurrence
  end

  def find_existing_occurrence
    next_occurrence = @series.scheduled_meetings.find_by(start_time: @next_meeting_time)
    return if next_occurrence.nil?

    if next_occurrence.cancelled?
      respond_with_flash_error(message: I18n.t(:text_agenda_item_move_next_meeting_cancelled))
    else
      @next_occurrence = next_occurrence.meeting
    end
  end

  def assign_drop_params # rubocop:disable Metrics/AbcSize
    @target_id, @position =
      if params[:type] == "to_current"
        meeting = Meeting.find_by(id: params[:current_meeting_id])
        section = meeting.sections.reorder(position: :desc).first
        [section&.id, section&.last_position]
      elsif params[:type] == "to_backlog"
        [@meeting.backlog.id, @meeting.backlog.last_position]
      else
        [params[:target_id], params[:position]]
      end
  end

  def assign_drop_results(call, meeting_agenda_item_section)
    if @target_id.nil?
      old_section     = meeting_agenda_item_section
      current_section = call.result.meeting_section
      section_changed = true
    else
      old_section     = call.result[:old_section]
      current_section = call.result[:current_section]
      section_changed = call.result[:section_changed]
    end

    [old_section, current_section, section_changed]
  end
end
