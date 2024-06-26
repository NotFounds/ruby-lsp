# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Listeners
    class SignatureHelp
      extend T::Sig
      include Requests::Support::Common

      sig do
        params(
          response_builder: ResponseBuilders::SignatureHelp,
          global_state: GlobalState,
          node_context: NodeContext,
          dispatcher: Prism::Dispatcher,
          typechecker_enabled: T::Boolean,
        ).void
      end
      def initialize(response_builder, global_state, node_context, dispatcher, typechecker_enabled)
        @typechecker_enabled = typechecker_enabled
        @response_builder = response_builder
        @global_state = global_state
        @index = T.let(global_state.index, RubyIndexer::Index)
        @node_context = node_context
        dispatcher.register(self, :on_call_node_enter)
      end

      sig { params(node: Prism::CallNode).void }
      def on_call_node_enter(node)
        return if @typechecker_enabled
        return unless self_receiver?(node)

        message = node.message
        return unless message

        methods = @index.resolve_method(message, @node_context.fully_qualified_name)
        return unless methods

        target_method = methods.first
        return unless target_method

        parameters = target_method.parameters
        name = target_method.name

        # If the method doesn't have any parameters, there's no need to show signature help
        return if parameters.empty?

        label = "#{name}(#{parameters.map(&:decorated_name).join(", ")})"

        arguments_node = node.arguments
        arguments = arguments_node&.arguments || []
        active_parameter = (arguments.length - 1).clamp(0, parameters.length - 1)

        # If there are arguments, then we need to check if there's a trailing comma after the end of the last argument
        # to advance the active parameter to the next one
        if arguments_node &&
            node.slice.byteslice(arguments_node.location.end_offset - node.location.start_offset) == ","
          active_parameter += 1
        end

        signature_help = Interface::SignatureHelp.new(
          signatures: [
            Interface::SignatureInformation.new(
              label: label,
              parameters: parameters.map { |param| Interface::ParameterInformation.new(label: param.name) },
              documentation: Interface::MarkupContent.new(
                kind: "markdown",
                value: markdown_from_index_entries("", methods),
              ),
            ),
          ],
          active_parameter: active_parameter,
        )
        @response_builder.replace(signature_help)
      end
    end
  end
end
