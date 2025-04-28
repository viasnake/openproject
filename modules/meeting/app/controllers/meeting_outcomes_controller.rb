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

class MeetingOutcomesController < ApplicationController
  include OpTurbo::ComponentStream
  include Meetings::AgendaComponentStreams

  before_action :set_meeting
  before_action :set_meeting_agenda_item, except: %i[edit cancel_edit update destroy]
  before_action :set_meeting_outcome, except: %i[new cancel_new create]
  before_action :authorize_global, only: %i[new create]
  before_action :authorize, except: %i[new create]

  def new
    update_all_via_turbo_stream

    if @meeting.in_progress? && !@meeting_agenda_item.in_backlog?
      render_base_outcome_component_via_turbo_stream(meeting: @meeting, meeting_agenda_item: @meeting_agenda_item,
                                                     meeting_outcome: nil, edit: true)
    else
      render_error_flash_message_via_turbo_stream(message: t("text_outcome_cannot_be_added"))
    end

    respond_with_turbo_streams
  end

  def cancel_new
    render_base_outcome_component_via_turbo_stream(meeting: @meeting, meeting_agenda_item: @meeting_agenda_item,
                                                   meeting_outcome: nil, edit: false)

    respond_with_turbo_streams
  end

  def create
    call = ::MeetingOutcomes::CreateService
             .new(user: current_user)
             .call(
               meeting_agenda_item: @meeting_agenda_item,
               notes: params[:meeting_outcome][:notes]
             )

    @meeting_outcome = call.result
    if call.success?
      render_base_outcome_component_via_turbo_stream(meeting: @meeting, meeting_agenda_item: @meeting_agenda_item,
                                                     meeting_outcome: @meeting_outcome, edit: false)
    else
      render_base_error_in_flash_message_via_turbo_stream(call.errors)
    end

    update_all_via_turbo_stream

    respond_with_turbo_streams
  end

  def edit
    if @meeting_outcome.editable?
      @meeting_agenda_item = @meeting_outcome.meeting_agenda_item
      render_base_outcome_component_via_turbo_stream(meeting: @meeting, meeting_agenda_item: @meeting_agenda_item,
                                                     meeting_outcome: @meeting_outcome, edit: true)
    else
      render_error_flash_message_via_turbo_stream(message: t("text_meeting_not_editable_anymore"))
      update_all_via_turbo_stream
    end

    respond_with_turbo_streams
  end

  def cancel_edit
    @meeting_agenda_item = @meeting_outcome.meeting_agenda_item
    render_base_outcome_component_via_turbo_stream(meeting: @meeting, meeting_agenda_item: @meeting_agenda_item,
                                                   meeting_outcome: @meeting_outcome, edit: false)

    respond_with_turbo_streams
  end

  def update
    @meeting_agenda_item = @meeting_outcome.meeting_agenda_item
    call = ::MeetingOutcomes::UpdateService
             .new(user: current_user, model: @meeting_outcome)
             .call(
               meeting_agenda_item: @meeting_agenda_item,
               notes: params[:meeting_outcome][:notes]
             )

    if call.success?
      render_base_outcome_component_via_turbo_stream(meeting: @meeting, meeting_agenda_item: @meeting_agenda_item,
                                                     meeting_outcome: call.result, edit: false)
    else
      render_base_error_in_flash_message_via_turbo_stream(call.errors)
    end

    update_all_via_turbo_stream

    respond_with_turbo_streams
  end

  def destroy
    @meeting_agenda_item = @meeting_outcome.meeting_agenda_item
    call = ::MeetingOutcomes::DeleteService
      .new(user: current_user, model: @meeting_outcome)
      .call

    if call.success?
      render_base_outcome_component_via_turbo_stream(meeting: @meeting, meeting_agenda_item: @meeting_agenda_item,
                                                     meeting_outcome: nil, edit: false)
      update_header_component_via_turbo_stream
    else
      render_base_error_in_flash_message_via_turbo_stream(call.errors)
    end

    update_all_via_turbo_stream

    respond_with_turbo_streams
  end

  private

  def set_meeting
    @meeting = Meeting.find(params[:meeting_id])
    @project = @meeting.project # required for authorization via before_action
  end

  def set_meeting_agenda_item
    @meeting_agenda_item = MeetingAgendaItem.find(params[:meeting_agenda_item_id])
  end

  def set_meeting_outcome
    @meeting_outcome = MeetingOutcome.find(params[:id])
  end
end
