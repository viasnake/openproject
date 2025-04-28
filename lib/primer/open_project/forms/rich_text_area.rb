# frozen_string_literal: true

module Primer
  module OpenProject
    module Forms
      # :nodoc:
      class RichTextArea < Primer::Forms::BaseComponent
        include AngularHelper

        delegate :builder, :form, to: :@input

        def initialize(input:, rich_text_options:)
          super()
          @input = input
          @rich_text_data = rich_text_options.delete(:data) { {} }
          @rich_text_options = rich_text_options
        end
      end
    end
  end
end
