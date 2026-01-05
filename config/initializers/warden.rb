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

namespace = OpenProject::Authentication::Strategies::Warden

strategies = [
  [:basic_auth_failure, namespace::BasicAuthFailure,  "Basic"],
  [:global_basic_auth,  namespace::GlobalBasicAuth,   "Basic"],
  [:user_basic_auth,    namespace::UserBasicAuth,     "Basic"],
  [:oauth,              namespace::DoorkeeperOAuth,   "Bearer"],
  [:anonymous_fallback, namespace::AnonymousFallback, "Basic"],
  [:jwt_oidc,           namespace::JwtOidc,           "Bearer"],
  [:session,            namespace::Session,           "Session"]
]

strategies.each do |name, clazz, auth_scheme|
  OpenProject::Authentication.add_strategy(name, clazz, auth_scheme)
end

OpenProject::Authentication.update_strategies(OpenProject::Authentication::Scope::API_V3, { store: false }) do |_|
  %i[global_basic_auth
     user_basic_auth
     basic_auth_failure
     oauth
     jwt_oidc
     session
     anonymous_fallback]
end

OpenProject::Authentication.update_strategies(OpenProject::Authentication::Scope::SCIM_V2, { store: false }) do |_|
  %i[oauth jwt_oidc]
end

OpenProject::Authentication.update_strategies(OpenProject::Authentication::Scope::MCP_SCOPE, { store: false }) do |_|
  %i[oauth jwt_oidc]
end

Rails.application.configure do |app|
  app.config.middleware.use OpenProject::Authentication::Manager, intercept_401: false # rubocop:disable Naming/VariableNumber
end
