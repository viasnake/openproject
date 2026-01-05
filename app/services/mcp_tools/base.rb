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
  class Base
    class << self
      def qualified_name
        "tools/#{name}"
      end

      def default_title(title = nil)
        @default_title = title if title.present?

        @default_title
      end

      def default_description(description = nil)
        @default_description = description if description.present?

        @default_description
      end

      def name(name = nil)
        @name = name if name.present?

        @name
      end

      def input_schema(schema = nil)
        @input_schema = schema if schema.present?

        @input_schema
      end

      def output_schema(schema = nil)
        @output_schema = schema if schema.present?

        @output_schema
      end

      def tool
        config = McpConfiguration.find_by(identifier: qualified_name)
        return nil if config.nil?

        implementation = self
        MCP::Tool.define(
          name:,
          title: config.title,
          description: config.description,
          input_schema:,
          output_schema:
        ) do |opts|
          implementation.new(tool_context: self).handle_request(**opts)
        end
      end
    end

    def initialize(tool_context:)
      @tool_context = tool_context
    end

    def handle_request(**)
      result = call(**)

      if Rails.env.local?
        # We are only validating the output during development, so we can see errors during dev, but do not break the
        # API in production due to minor schema differences.
        @tool_context.output_schema.validate_result(result.to_json)
      end

      MCP::Tool::Response.new([{ type: "text", text: result.to_json }], structured_content: result)
    end

    # Intended to be implemented by subclasses. It should return a structured result (e.g. a Hash or Array).
    def call(**)
      raise NotImplemented, "#{self.class} needs to implement #call method"
    end
  end
end
