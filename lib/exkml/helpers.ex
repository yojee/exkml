defmodule Exkml.Helpers do
  defmacro on_enter(name, event, state, body) do
    quote do
      def handle_event(:start_element, {unquote(name), _attrs} = unquote(event), unquote(state)) do
        {:ok, unquote(body[:do])}
      end
    end
  end

  defmacro on_exit(name, state, body) do
    quote do
      def handle_event(:end_element, unquote(name), unquote(state)) do
        {:ok, unquote(body[:do])}
      end
    end
  end

  defmacro textof(path, state, body) do
    stack =
      path
      |> String.split("/")
      |> Enum.reverse()

    quote do
      def handle_event(:characters, c, %{stack: unquote(stack)} = unquote(state)) do
        var!(text) = c
        {:ok, unquote(body[:do])}
      end
    end
  end
end
