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

require "spec_helper"

RSpec.describe "Projects", "editing settings", :js do
  include_context "ng-select-autocomplete helpers"

  let(:permissions) { %i(edit_project view_project_attributes edit_project_attributes) }

  current_user do
    create(:user, member_with_permissions: { project => permissions })
  end

  shared_let(:project) do
    create(:project, :with_status, name: "Foo project", identifier: "foo-project")
  end

  it "hides the field whose functionality is presented otherwise" do
    visit project_settings_general_path(project.id)

    expect(page).to have_no_text :all, "Active"
    expect(page).to have_no_text :all, "Identifier"
  end

  describe "identifier edit" do
    it "updates the project identifier" do
      visit projects_path
      click_on project.name
      click_on "Project settings"
      click_on "Change identifier"

      expect(page).to have_content "Change the project's identifier".upcase
      expect(page).to have_current_path "/projects/foo-project/identifier"

      fill_in "project[identifier]", with: "foo-bar"
      click_on "Update"

      expect(page).to have_content "Successful update."
      expect(page)
        .to have_current_path %r{/projects/foo-bar/settings/general}
      expect(Project.first.identifier).to eq "foo-bar"
    end

    it "displays error messages on invalid input" do
      visit project_identifier_path(project)

      fill_in "project[identifier]", with: "FOOO"
      click_on "Update"

      expect(page).to have_content "Identifier is invalid."
      expect(page).to have_current_path "/projects/foo-project/identifier"
    end
  end

  describe "editing basic details" do
    before do
      Pages::Projects::Settings::General.new(project).visit!
    end

    it "updates the basic details" do
      within_section "Basic details" do
        fill_in "Name", with: "Bar project"
        fill_in_rich_text "Description", with: "a long and verbose project description."

        click_on "Update details"
      end

      expect_and_dismiss_flash type: :success, message: "Successful update."

      within_section "Basic details" do
        expect(page).to have_field "Name", with: "Bar project"
        expect(page).to have_selector :rich_text, "Description", text: "a long and verbose project description."
      end
    end

    it "displays validation error on invalid input" do
      within_section "Basic details" do
        fill_in "Name", with: ""
        click_on "Update details"

        expect(page).to have_field "Name", with: "", validation_error: "Name can't be blank."

        fill_in "Name", with: "A" * 256
        click_on "Update details"

        expect(page).to have_field "Name", with: "A" * 256, validation_error: "Name is too long (maximum is 255 characters)."
      end
    end
  end

  describe "editing project status" do
    let(:status_field) { FormFields::SelectFormField.new :status }

    before do
      Pages::Projects::Settings::General.new(project).visit!
    end

    it "updates the project status and description" do
      within_section "Project status" do
        status_field.select_option "At risk"
        fill_in_rich_text "Project status description", with: "Light-years behind 🥺"

        click_on "Update status"
      end

      expect_and_dismiss_flash type: :success, message: "Successful update."

      within_section "Project status" do
        status_field.expect_selected "AT RISK"
        expect(page).to have_selector :rich_text, "Project status description", text: "Light-years behind 🥺"
      end
    end

    it "unsets the project status" do
      within_section "Project status" do
        status_field.select_option "Not set"

        click_on "Update status"
      end

      expect_and_dismiss_flash type: :success, message: "Successful update."

      within_section "Project status" do
        status_field.expect_selected "NOT SET"
      end
    end
  end

  describe "editing project relations" do
    let(:parent_field) { FormFields::SelectFormField.new :parent }
    let(:parent_project) { create(:project, name: "New parent project") }

    before do
      project.update_attribute(:parent, parent_project)
    end

    context "with a user allowed to see parent project" do
      current_user { create(:user, member_with_permissions: { project => permissions, parent_project => permissions }) }

      it "updates the parent project" do
        Pages::Projects::Settings::General.new(project).visit!

        within_section "Project relations" do
          parent_field.expect_selected "New parent project"
          click_on "Update parent project"
        end

        expect_and_dismiss_flash type: :success, message: "Successful update."

        within_section "Project relations" do
          parent_field.expect_selected "New parent project"
        end
      end
    end

    context "with a user not allowed to see the parent project" do
      it "can update the project without destroying the relation to the parent" do
        Pages::Projects::Settings::General.new(project).visit!

        within_section "Project relations" do
          parent_field.expect_selected I18n.t(:"api_v3.undisclosed.parent")
          click_on "Update parent project"
        end

        expect_and_dismiss_flash type: :success, message: "Successful update."

        project.reload
        expect(project.parent).to eq parent_project
      end
    end
  end
end
