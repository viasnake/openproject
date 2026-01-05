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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

module McpTools
  class SearchProject < Base
    # TODO: The mcp gem does not support pagination, so we only limit the number of results for now
    MAX_SIZE = 100

    default_title "Search projects"
    default_description "Search projects matching all of the passed input parameters. " \
                        "Parameters not passed are ignored. Results are limited to a maximum of #{MAX_SIZE} projects."

    name "search_project"

    input_schema(
      properties: {
        name: { type: "string", description: "Name of the project. Accepts partial project names, not case-sensitive." },
        identifier: { type: "string", description: "Project indentifier. Case-sensitive, matching exactly." },
        status_code: { type: "string", enum: Project.status_codes.keys, description: "The project status." }
      }
    )

    output_schema(
      type: :array,
      items: JsonSchemaLoader.new.load("project_model")
    )

    def call(name: nil, identifier: nil, status_code: nil)
      query = { name:, identifier:, status_code: }.compact
      if query.present?
        projects = projects_for_query(query)
        projects.map { |p| API::V3::Projects::ProjectRepresenter.create(p, current_user: User.current) }
      else
        []
      end
    end

    private

    def projects_for_query(query)
      name = query.delete(:name)
      projects = Project.visible.where(query).limit(MAX_SIZE)
      projects = projects.where("name ILIKE '%#{OpenProject::SqlSanitization.quoted_sanitized_sql_like(name)}%'") if name
      projects
    end
  end
end
