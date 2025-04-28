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
  class ItemComponent::ShowComponent < ApplicationComponent
    include ApplicationHelper
    include AvatarHelper
    include OpTurbo::Streamable
    include OpPrimer::ComponentHelpers
    include Redmine::I18n

    def initialize(meeting_agenda_item:, first_and_last: [])
      super

      @meeting_agenda_item = meeting_agenda_item
      @meeting = meeting_agenda_item.meeting
      @series = @meeting.recurring_meeting
      @first_and_last = first_and_last
    end

    def wrapper_uniq_by
      @meeting_agenda_item.id
    end

    private

    def drag_and_drop_enabled?
      !@meeting.closed? && User.current.allowed_in_project?(:manage_agendas, @meeting.project)
    end

    def edit_enabled?
      !@meeting.closed? && User.current.allowed_in_project?(:manage_agendas, @meeting.project)
    end

    def add_outcome_action?
      @meeting_agenda_item.editable? &&
        @meeting.in_progress? &&
        !@meeting_agenda_item.outcomes.exists? &&
        !@meeting_agenda_item.in_backlog?
    end

    def first?
      @first ||=
        if @first_and_last.first
          @first_and_last.first == @meeting_agenda_item
        else
          @meeting_agenda_item.first?
        end
    end

    def last?
      @last ||=
        if @first_and_last.last
          @first_and_last.last == @meeting_agenda_item
        else
          @meeting_agenda_item.last?
        end
    end

    def meeting_closed?
      !@meeting.open?
    end

    def recurring_meeting?
      @series.present?
    end

    def edit_action_item(menu)
      menu.with_item(label: t("label_edit"),
                     href: edit_meeting_agenda_item_path(@meeting_agenda_item.meeting, @meeting_agenda_item),
                     content_arguments: {
                       data: { "turbo-stream": true }
                     }) do |item|
        item.with_leading_visual_icon(icon: :pencil)
      end
    end

    def add_note_action_item(menu)
      menu.with_item(label: t("label_agenda_item_add_notes"),
                     href: edit_meeting_agenda_item_path(@meeting_agenda_item.meeting, @meeting_agenda_item,
                                                         display_notes_input: true),
                     content_arguments: {
                       data: { "turbo-stream": true }
                     }) do |item|
        item.with_leading_visual_icon(icon: :note)
      end
    end

    def add_outcome_action_item(menu)
      menu.with_item(label: t("label_agenda_item_add_outcome"),
                     href: new_meeting_outcome_path(@meeting_agenda_item.meeting,
                                                    meeting_agenda_item_id: @meeting_agenda_item&.id),
                     content_arguments: {
                       data: { "turbo-stream": true }
                     }) do |item|
        item.with_leading_visual_icon(icon: :plus)
      end
    end

    def copy_action_item(menu)
      url = meeting_url(@meeting, anchor: "item-#{@meeting_agenda_item.id}")
      menu.with_item(label: t("button_copy_link_to_clipboard"),
                     tag: :"clipboard-copy",
                     content_arguments: { value: url }) do |item|
        item.with_leading_visual_icon(icon: :copy)
      end
    end

    def move_to_next_meeting_action_item(menu)
      return if in_template?
      return if @series.nil?

      next_date = @series.next_occurrence(from_time: @meeting.start_time)
      return if next_date.nil?

      menu.with_item(
        label: t(:label_agenda_item_move_to_next),
        href: move_to_next_meeting_agenda_item_path(@meeting_agenda_item.meeting,
                                                    @meeting_agenda_item,
                                                    datetime: next_date.iso8601),
        form_arguments: {
          method: :post,
          data: {
            confirm: t(:text_agenda_item_move_next_meeting,
                       date: format_date(next_date),
                       time: format_time(next_date, include_date: false)),
            "turbo-stream": true
          }
        }
      ) do |item|
        item.with_leading_visual_icon(icon: "arrow-right")
      end
    end

    def move_actions(menu)
      move_action_item(menu, :highest, t("label_agenda_item_move_to_top"), "move-to-top") unless first?
      move_action_item(menu, :higher, t("label_agenda_item_move_up"), "chevron-up") unless first?
      move_action_item(menu, :lower, t("label_agenda_item_move_down"), "chevron-down") unless last?
      move_action_item(menu, :lowest, t("label_agenda_item_move_to_bottom"), "move-to-bottom") unless last?
    end

    def delete_action_item(menu)
      label = @meeting_agenda_item.work_package_id.present? ? t(:label_agenda_item_remove) : t(:text_destroy)
      menu.with_item(label:,
                     scheme: :danger,
                     href: meeting_agenda_item_path(@meeting_agenda_item.meeting, @meeting_agenda_item),
                     form_arguments: {
                       method: :delete, data: { confirm: t("text_are_you_sure"), "turbo-stream": true }
                     }) do |item|
        item.with_leading_visual_icon(icon: :trash)
      end
    end

    def move_action_item(menu, move_to, label_text, icon)
      menu.with_item(label: label_text,
                     href: move_meeting_agenda_item_path(@meeting_agenda_item.meeting, @meeting_agenda_item,
                                                         move_to:),
                     form_arguments: {
                       method: :put, data: { "turbo-stream": true }
                     }) do |item|
        item.with_leading_visual_icon(icon:)
      end
    end

    def move_to_backlog_action_item(menu)
      menu.with_item(label: I18n.t(:label_agenda_item_move_to_backlog),
                     tag: :button,
                     content_arguments: { data: {
                       action: "click->add-meeting-params#interceptMoveTo",
                       href: drop_meeting_agenda_item_path(@meeting_agenda_item.meeting, @meeting_agenda_item, type: :to_backlog)
                     } }) do |item|
        item.with_leading_visual_icon(icon: "discussion-outdated")
      end
    end

    def move_to_current_meeting_action_item(menu)
      menu.with_item(label: I18n.t(:label_agenda_item_move_to_current_meeting),
                     tag: :button,
                     content_arguments: { data: {
                       action: "click->add-meeting-params#interceptMoveTo",
                       href: drop_meeting_agenda_item_path(@meeting_agenda_item.meeting, @meeting_agenda_item, type: :to_current)
                     } }) do |item|
        item.with_leading_visual_icon(icon: "cross-reference")
      end
    end

    def duration_color_scheme
      if @meeting.end_time < @meeting_agenda_item.end_time
        :danger
      else
        :subtle
      end
    end

    def notes_classes
      if @meeting.open?
        "op-uc-container override"
      else
        "op-uc-container override muted-color"
      end
    end

    def move_to_next_meeting_enabled?
      edit_enabled? && @meeting.recurring? && @meeting.recurring_meeting&.next_occurrence.present? && !in_template?
    end

    def in_backlog?
      @meeting_agenda_item.meeting_section.backlog?
    end

    def in_template?
      @meeting.templated?
    end
  end
end
