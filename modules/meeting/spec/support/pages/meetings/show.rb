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

require_relative "base"

module Pages::Meetings
  class Show < Base
    include ::Components::Autocompleter::NgSelectAutocompleteHelpers
    attr_accessor :meeting

    def initialize(meeting)
      self.meeting = meeting

      super(meeting.project)
    end

    def expect_no_invited
      expect(page)
        .to have_content("#{Meeting.human_attribute_name(:participants_invited)}: -")
    end

    def expect_no_attended
      expect(page)
        .to have_content("#{Meeting.human_attribute_name(:participants_attended)}: -")
    end

    def expect_invited(*users)
      users.each do |user|
        within(meeting_details_container) do
          expect(page)
            .to have_link(user.name)
        end
      end
    end

    def expect_uninvited(*users)
      users.each do |user|
        within(meeting_details_container) do
          expect(page)
            .to have_no_link(user.name)
        end
      end
    end

    def expect_date_time(expected)
      expect(page)
        .to have_content("Start time: #{expected}")
    end

    def expect_link_to_location(location)
      within(meeting_details_container) do
        expect(page).to have_link location
      end
    end

    def expect_plaintext_location(location)
      within(meeting_details_container) do
        expect(page).to have_no_link location
        expect(page).to have_text(location)
      end
    end

    def path
      project_meeting_path(meeting.project, meeting)
    end

    def expect_empty
      expect(page).to have_no_css('[id^="meeting-agenda-items-item-component"]')
    end

    def trigger_dropdown_menu_item(name)
      click_link_or_button "op-meetings-header-action-trigger"
      click_link_or_button name
    end

    def trigger_change_poll
      script = <<~JS
        var target = document.querySelector('#content-wrapper');
        var controller = window.Stimulus.getControllerForElementAndIdentifier(target, 'poll-for-changes')
        controller.triggerTurboStream();
      JS

      page.execute_script(script)
    end

    def add_agenda_item(type: MeetingAgendaItem, save: true, &)
      page.within("#meeting-agenda-items-new-button-component") do
        click_on I18n.t(:button_add)
        click_on type.model_name.human
      end

      in_agenda_form do
        yield
        click_on("Save") if save
      end
    end

    def expect_modal(...)
      expect(page).to have_modal(...)
    end

    def expect_no_add_form
      expect(page).not_to have_test_selector("#meeting-agenda-items-form-component")
    end

    def add_agenda_item_to_section(section:, type: MeetingAgendaItem, save: true, &)
      select_section_action(section, type.model_name.human)

      within("#meeting-sections-show-component-#{section.id}") do
        in_agenda_form do
          yield
          click_on("Save") if save
        end
      end
    end

    def cancel_edit_form(item)
      in_edit_form(item) do
        click_on I18n.t(:button_cancel)
        expect(page).to have_no_link I18n.t(:button_cancel)
      end
    end

    def in_edit_form(item, &)
      page.within("#meeting-agenda-items-item-component-#{item.id}", &)
    end

    def in_agenda_form(&)
      page.within("#meeting-agenda-items-form-component", &)
    end

    def assert_agenda_order!(*titles)
      retry_block do
        found = page.all(:test_id, "op-meeting-agenda-title").map(&:text)
        raise "Expected order of agenda items #{titles.inspect}, but found #{found.inspect}" if titles != found
      end
    end

    def remove_agenda_item(item)
      accept_confirm(I18n.t("text_are_you_sure")) do
        action = item.work_package ? I18n.t(:label_agenda_item_remove) : I18n.t(:button_delete)
        select_action(item, action)
      end

      title = item.work_package ? item.work_package.subject : item.title
      expect_no_agenda_item(title:)
    end

    def expect_agenda_item(title:)
      expect(page).to have_test_selector("op-meeting-agenda-title", text: title)
    end

    def expect_agenda_item_in_section(title:, section:)
      within("#meeting-sections-show-component-#{section.id}") do
        expect_agenda_item(title:)
      end
    end

    def expect_agenda_link(item)
      if item.is_a?(WorkPackage)
        expect(page).to have_css("[id^='meeting-agenda-items-item-component-']", text: item.subject)
      else
        expect(page).to have_css("#meeting-agenda-items-item-component-#{item.id}", text: item.work_package.subject)
      end
    end

    def expect_agenda_author(name)
      expect(page).to have_test_selector("op-principal", text: name)
    end

    def expect_undisclosed_agenda_link(item)
      expect(page).to have_css("#meeting-agenda-items-item-component-#{item.id}",
                               text: I18n.t(:label_agenda_item_undisclosed_wp, id: item.work_package_id))
    end

    def expect_no_agenda_item(title:)
      expect(page).not_to have_test_selector("op-meeting-agenda-title", text: title)
    end

    def expect_agenda_action_menu(item)
      expect(page)
        .to have_css("#meeting-agenda-items-item-component-#{item.id} #{test_selector('op-meeting-agenda-actions')}")
    end

    def expect_no_agenda_action_menu(item)
      expect(page)
        .to have_no_css("#meeting-agenda-items-item-component-#{item.id} #{test_selector('op-meeting-agenda-actions')}")
    end

    def select_action(item, action)
      open_menu(item) do
        click_on action
      end
    end

    def open_menu(item, &)
      retry_block do
        page.within("#meeting-agenda-items-item-component-#{item.id}") do
          page.find_test_selector("op-meeting-agenda-actions").click
        end
        page.find(".Overlay")
      end

      page.within(".Overlay", &)
    end

    def select_outcome_action(action)
      retry_block do
        page.find_test_selector("op-meeting-outcome-actions").click
        page.find(".Overlay")
      end

      page.within(".Overlay") do
        click_on action
      end
    end

    def expect_no_outcome_actions
      expect(page).to have_no_css("op-meeting-outcome-actions")
    end

    def expect_no_outcome_action(item)
      retry_block do
        page.within("#meeting-agenda-items-item-component-#{item.id}") do
          page.find_test_selector("op-meeting-agenda-actions").trigger("click")
        end
        page.find(".Overlay")
      end

      page.within(".Overlay") do
        expect(page).to have_no_text("Add outcome")
      end
    end

    def select_section_action(section, action)
      retry_block do
        click_on_section_menu(section)
        page.find(".Overlay")
      end

      page.within(".Overlay") do
        click_on action
      end
    end

    def click_on_section_menu(section)
      page.within_test_selector("meeting-section-header-container-#{section.id}") do
        page.find_test_selector("meeting-section-action-menu").click
      end
    end

    def in_outcome_component(item, &)
      page.within("#meeting-agenda-items-outcomes-base-component-#{item.id}", &)
    end

    def add_outcome(item, &)
      page.within("#meeting-agenda-items-outcomes-base-component-#{item.id}") do
        click_link_or_button "Outcome"
      end
      expect_outcome_form(item)
      page.within("#meeting-agenda-items-outcomes-input-component-#{item.id}", &)
    end

    def add_outcome_from_menu(item, &)
      select_action item, "Add outcome"
      expect_outcome_form(item)
      page.within("#meeting-agenda-items-outcomes-input-component-#{item.id}", &)
    end

    def expect_outcome_form(item)
      expect(page)
        .to have_css("#meeting-agenda-items-outcomes-input-component-#{item.id}")
    end

    def expect_outcome(text)
      expect(page).to have_css("#meeting-agenda-items-outcomes-show-notes-component", text:)
    end

    def expect_no_outcome(text)
      expect(page).to have_no_css("#meeting-agenda-items-outcomes-show-notes-component", text:)
    end

    def expect_no_outcome_button
      expect(page).to have_no_css("op-meeting-outcome--button")
    end

    def expect_backlog(collapsed:)
      expect(page).to have_css(".CollapsibleHeader", text: I18n.t("label_agenda_backlog"))

      if collapsed
        expect(page).to have_css(".CollapsibleHeader.CollapsibleHeader--collapsed")
        expect(page).to have_no_text(I18n.t("text_agenda_backlog"))
      else
        expect(page).to have_no_css(".CollapsibleHeader.CollapsibleHeader--collapsed")
        expect(page).to have_text(I18n.t("text_agenda_backlog"))
      end
    end

    def expect_series_backlog(collapsed:)
      expect(page).to have_css(".CollapsibleHeader", text: I18n.t("label_series_backlog"))

      if collapsed
        expect(page).to have_css(".CollapsibleHeader.CollapsibleHeader--collapsed")
        expect(page).to have_no_text(I18n.t("text_series_backlog"))
      else
        expect(page).to have_no_css(".CollapsibleHeader.CollapsibleHeader--collapsed")
        expect(page).to have_text(I18n.t("text_series_backlog"))
      end
    end

    def expect_backlog_count(count)
      within("#meeting-sections-backlogs-container-component") do
        expect(page).to have_css(".Counter", text: count)
      end
    end

    def expect_no_backlog
      expect(page).to have_no_css(".CollapsibleHeader")
    end

    def expect_empty_backlog
      within_backlog do
        expect(page).to have_text("Drag items here or create a new one")
        expect(page).to have_button("Add")
      end
    end

    def add_agenda_item_to_backlog(type: MeetingAgendaItem, &)
      select_backlog_action(type.model_name.human)

      within("#meeting-sections-backlogs-container-component") do
        in_agenda_form do
          yield
          click_on("Save")
        end
      end
    end

    def select_backlog_action(action)
      retry_block do
        click_on_backlog_menu
        page.find(".Overlay")
      end

      page.within(".Overlay") do
        click_on action
      end
    end

    def click_on_backlog_menu
      page.within("#meeting-sections-backlogs-header-component") do
        page.find_test_selector("meeting-section-action-menu").click
      end
    end

    def within_backlog(&)
      page.within("#meeting-sections-backlogs-container-component", &)
    end

    def click_on_backlog
      within_backlog do
        page.find(".CollapsibleHeader").click
      end
    end

    def clear_backlog
      retry_block do
        select_backlog_action(I18n.t("label_backlog_clear"))
        expect(page).to have_modal(I18n.t("label_backlog_clear"))
        page.within_modal(I18n.t("label_backlog_clear")) do
          click_on "Clear all"
        end
      end
    end

    def edit_agenda_item(item, &)
      select_action item, "Edit"
      expect_item_edit_form(item)
      page.within("#meeting-agenda-items-form-component-#{item.id}", &)
    end

    def expect_item_edit_form(item, visible: true)
      expect(page)
        .to have_conditional_selector(
          visible,
          "#meeting-agenda-items-form-component-#{item.id}"
        )
    end

    def expect_item_edit_title(item, value)
      page.within("#meeting-agenda-items-form-component-#{item.id}") do
        find_field("Title", with: value)
      end
    end

    def expect_item_edit_field_error(item, text)
      page.within("#meeting-agenda-items-form-component-#{item.id}") do
        expect(page).to have_css(".FormControl-inlineValidation", text:)
      end
    end

    def clear_item_edit_work_package_title
      ng_select_clear page.find(".op-meeting-agenda-item-form--title")
      expect(page).to have_css(".ng-input  ", value: nil)
    end

    def open_participant_form
      page.find_test_selector("manage-participants-button").click
      expect_modal("Participants")
    end

    def in_participant_form(&)
      page.within_modal("Participants", &)
    end

    def expect_participant(participant, invited: false, attended: false, editable: true)
      expect(page).to have_text(participant.name)
      expect(page).to have_field(id: "checkbox_invited_#{participant.id}", checked: invited, disabled: !editable)
      expect(page).to have_field(id: "checkbox_attended_#{participant.id}", checked: attended, disabled: !editable)
    end

    def expect_participant_invited(participant, invited: true)
      expect(page).to have_text(participant.name)
      expect(page).to have_field(id: "checkbox_invited_#{participant.id}", checked: invited)
    end

    def invite_participant(participant)
      id = "checkbox_invited_#{participant.id}"
      retry_block do
        check(id:)
        raise "Expected #{participant.id} to be invited now" unless page.has_checked_field?(id:)
      end
    end

    def expect_available_participants(count:)
      expect(page).to have_link(class: "op-principal--name", count:)
    end

    def close_meeting
      retry_block do
        click_on("Open")
        page.find(".Overlay")
      end

      page.within(".Overlay") do
        click_on("Closed")
      end
      expect(page).to have_link("Reopen meeting")
    end

    def close_meeting_from_in_progress
      page.within("#meetings-side-panel-state-component") do
        click_on("Close meeting")
      end
    end

    def start_meeting
      page.within("#meetings-side-panel-state-component") do
        click_on("Start meeting")
      end
    end

    def reopen_meeting
      click_on("Reopen meeting")
      expect(page).to have_link("Start meeting")
    end

    def close_dialog
      click_on(class: "Overlay-closeButton")
    end

    def meeting_details_container
      find_by_id("meetings-side-panel-details-component")
    end

    def in_latest_section_form(&)
      sections = all(".op-meeting-section-container")
      last_except_backlog = sections[-2]
      page.within(last_except_backlog, &)
    end

    def add_section(&)
      retry_block do
        page.within("#meeting-agenda-items-new-button-component") do
          click_on I18n.t(:button_add)
          click_on "Section"
          # wait for the disabled button, indicating the turbo streams are applied
          expect(page).to have_css("#meeting-agenda-items-new-button-component button[disabled='disabled']")
        end
      end

      in_latest_section_form(&)
    end

    def expect_section(title:)
      expect(page).to have_css(".op-meeting-section-container", text: title)
    end

    def expect_no_section(title:)
      expect(page).to have_no_css(".op-meeting-section-container", text: title)
    end

    def expect_section_duration(section:, duration_text:)
      page.within_test_selector("meeting-section-header-container-#{section.id}") do
        expect(page).to have_text(duration_text)
      end
    end

    def edit_section(section, &)
      select_section_action(section, "Edit")

      page.within_test_selector("meeting-section-header-container-#{section.id}", &)
    end

    def remove_section(section)
      accept_confirm do
        select_section_action(section, "Delete")
      end
    end

    def expect_backlog_actions(item, series: false)
      open_menu(item) do
        expect(page).to have_css(".ActionListItem-label", text: "Edit")
        expect(page).to have_css(".ActionListItem-label", text: "Add notes")
        expect(page).to have_css(".ActionListItem-label", text: "Move to current meeting")
        expect(page).to have_css(".ActionListItem-label", text: "Delete")

        expect(page).to have_no_css(".ActionListItem-label", text: "Move to backlog")
        expect(page).to have_no_css(".ActionListItem-label", text: "Add outcome")
        if series
          expect(page).to have_no_css(".ActionListItem-label", text: "Move to next meeting")
        end
      end

      page.within("#meeting-agenda-items-item-component-#{item.id}") do
        page.find_test_selector("op-meeting-agenda-actions").click
      end
    end

    def expect_non_backlog_actions(item, series: false)
      open_menu(item) do
        expect(page).to have_css(".ActionListItem-label", text: "Move to backlog")
        expect(page).to have_no_css(".ActionListItem-label", text: "Move to current meeting")
        if series
          expect(page).to have_css(".ActionListItem-label", text: "Move to next meeting")
        end
      end

      page.within("#meeting-agenda-items-item-component-#{item.id}") do
        page.find_test_selector("op-meeting-agenda-actions").click
      end
    end

    def expect_no_backlog_header_actions
      within_backlog do
        expect { page.find_test_selector("meeting-section-action-menu") }.to raise_error(Capybara::ElementNotFound)
      end
    end

    def expect_blankslate
      expect(page).to have_test_selector("meeting-blankslate")
    end
  end
end
