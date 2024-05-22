#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2023 the OpenProject GmbH
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

module WorkPackages
  module ActivitiesTab
    module Journals
      class ShowComponent < ApplicationComponent
        include ApplicationHelper
        include AvatarHelper
        include JournalFormatter
        include OpPrimer::ComponentHelpers
        include OpTurbo::Streamable

        def initialize(journal:)
          super

          @journal = journal
        end

        private

        def wrapper_uniq_by
          @journal.id
        end

        def wrapper_data_attributes
          {
            controller: "work-packages--activities-tab--show",
            "application-target": "dynamic",
            "work-packages--activities-tab--show-activity-url-value": activity_url
          }
        end

        def activity_url
          "#{project_work_package_url(@journal.journable.project, @journal.journable)}/activity#{activity_anchor}"
        end

        def activity_anchor
          "#activity-#{@journal.version}"
        end

        def data_type
          @journal.data_type
        end

        def editable?
          @journal.user == User.current
        end

        def initial_version?
          @journal.version == 1
        end

        def updated?
          return false if initial_version?

          @journal.updated_at - @journal.created_at > 5.seconds
        end

        def copy_url_action_item(menu)
          menu.with_item(label: t("button_copy_link_to_clipboard"),
                         tag: :button,
                         content_arguments: {
                           data: {
                             action: "click->work-packages--activities-tab--show#copyActivityUrlToClipboard"
                           }
                         }) do |item|
            item.with_leading_visual_icon(icon: :copy)
          end
        end

        def edit_action_item(menu)
          # menu.with_item(label: t("label_edit"),
          #                href: edit_work_package_activity_path(@journal.journable, @journal),
          #                content_arguments: {
          #                  data: { "turbo-stream": true }
          #                }) do |item|
          #   item.with_leading_visual_icon(icon: :pencil)
          # end
          menu.with_item(label: t("label_edit"),
                         tag: :button,
                         content_arguments: {
                           data: {
                             action: "click->work-packages--activities-tab--show#edit"
                           }
                         }) do |item|
            item.with_leading_visual_icon(icon: :pencil)
          end
        end
      end
    end
  end
end
