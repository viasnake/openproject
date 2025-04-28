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
module Projects
  module Settings
    class StatusForm < ApplicationForm
      include ProjectStatusHelper

      form do |f|
        f.autocompleter(
          name: :status_code,
          label: attribute_name(:status_code),
          include_blank: true,
          autocomplete_options: {
            decorated: true,
            clearable: false,
            focusDirectly: false,
            data: { qa_field_name: "status" }
          }
        ) do |select|
          [nil, *Project.status_codes.keys].map do |status_code|
            select.option(
              label: project_status_name(status_code),
              value: status_code,
              classes: "project-status--name #{project_status_css_class(status_code)}",
              selected: model.status_code == status_code
            )
          end
        end

        f.rich_text_area(
          name: :status_explanation,
          label: attribute_name(:status_explanation),
          rich_text_options: {
            showAttachments: false,
            data: { qa_field_name: "statusExplanation" }
          }
        )
      end
    end
  end
end
