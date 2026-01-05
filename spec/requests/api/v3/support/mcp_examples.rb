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

require "spec_helper"

RSpec.shared_examples_for "MCP result response" do
  let(:json_rpc_response_schema) do
    {
      required: %w[jsonrpc id result],
      properties: {
        id: { type: "string" },
        jsonrpc: { type: "string", enum: ["2.0"] },
        result: { type: "object" }
      }
    }
  end

  it "returns a success" do
    subject
    expect(last_response).to have_http_status(200)
  end

  it "has no WWW-Authenticate header" do
    subject
    expect(last_response.headers["WWW-Authenticate"]).to be_nil
  end

  it "fulfills the schema of a JSON RPC response" do
    subject
    expect(last_response.body).to match_json_schema(json_rpc_response_schema)
  end
end

RSpec.shared_examples_for "MCP response with structured content" do
  let(:result_schema) do
    {
      required: %w[result],
      properties: {
        result: {
          required: %w[isError content structuredContent],
          properties: {
            isError: { type: "boolean" },
            content: { type: "array" },
            structuredContent: { type: ["object", "array"] }
          }
        }
      }
    }
  end

  include_context "MCP result response"

  it "fulfills the schema of a structured MCP response" do
    subject
    expect(last_response.body).to match_json_schema(json_rpc_response_schema)
  end
end

RSpec.shared_examples_for "MCP error response" do
  let(:json_rpc_response_schema) do
    {
      required: %w[jsonrpc id error],
      properties: {
        id: { type: "string" },
        jsonrpc: { type: "string", enum: ["2.0"] },
        error: {
          type: "object",
          required: %w[code message data],
          properties: {
            code: { type: "number" },
            message: { type: "string" },
            data: { type: "string" }
          }
        }
      }
    }
  end

  it "returns a success" do
    subject
    expect(last_response).to have_http_status(200)
  end

  it "has no WWW-Authenticate header" do
    subject
    expect(last_response.headers["WWW-Authenticate"]).to be_nil
  end

  it "fulfills the schema of a JSON RPC response" do
    subject
    expect(last_response.body).to match_json_schema(json_rpc_response_schema)
  end
end

RSpec.shared_examples_for "MCP unauthenticated response" do
  it "returns a 401 Unauthenticated" do
    subject
    expect(last_response).to have_http_status(401)
  end

  it "has a WWW-Authenticate header" do
    subject
    expect(last_response.headers["WWW-Authenticate"]).to be_present
  end
end
