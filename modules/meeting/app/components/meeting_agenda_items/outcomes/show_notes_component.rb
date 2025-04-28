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

module MeetingAgendaItems
  class Outcomes::ShowNotesComponent < ApplicationComponent
    include ApplicationHelper
    include OpTurbo::Streamable
    include OpPrimer::ComponentHelpers

    def initialize(meeting_outcome:)
      super

      @meeting_outcome = meeting_outcome
      @agenda_item = meeting_outcome.meeting_agenda_item
      @meeting = @agenda_item.meeting
    end

    private

    def edit_enabled?
      @meeting.in_progress? &&
        User.current.allowed_in_project?(:manage_outcomes, @meeting.project) &&
        !@agenda_item.in_backlog?
    end

    def edit_action_item(menu)
      menu.with_item(label: t("label_agenda_outcome_edit"),
                     href: edit_meeting_outcome_path(@meeting, @meeting_outcome),
                     content_arguments: {
                       data: { "turbo-stream": true }
                     }) do |item|
        item.with_leading_visual_icon(icon: :pencil)
      end
    end

    def copy_action_item(menu)
      url = meeting_url(@meeting, anchor: "outcome-#{@meeting_outcome.id}")
      menu.with_item(label: t("button_copy_link_to_clipboard"),
                     tag: :"clipboard-copy",
                     content_arguments: { value: url }) do |item|
        item.with_leading_visual_icon(icon: :copy)
      end
    end

    def delete_action_item(menu)
      menu.with_item(label: t("label_agenda_outcome_delete"),
                     scheme: :danger,
                     href: meeting_outcome_path(@meeting, @meeting_outcome),
                     form_arguments: {
                       method: :delete, data: { confirm: t("text_are_you_sure"), "turbo-stream": true }
                     }) do |item|
        item.with_leading_visual_icon(icon: :trash)
      end
    end
  end
end
