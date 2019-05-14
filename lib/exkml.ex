defmodule Exkml do
  @moduledoc """
  Documentation for Exkml.
  """
  import Exkml.Helpers

  defmodule Point do
    defstruct [:x, :y, :z]
  end

  defmodule Line do
    defstruct [:points]
  end

  defmodule Polygon do
    defstruct [:outer_boundary, inner_boundaries: []]
  end

  defmodule Multigeometry do
    defstruct geoms: []
  end

  defmodule KMLParseError do
    defexception [:message, :event]
  end

  defp do_str_to_point([x, y]) do
    with {x, _} <- Float.parse(x),
         {y, _} <- Float.parse(y) do
      {:ok, %Point{x: x, y: y}}
    else
      _ -> :error
    end
  end

  defp do_str_to_point([x, y, z]) do
    with {x, _} <- Float.parse(x),
         {y, _} <- Float.parse(y),
         {z, _} <- Float.parse(z) do
      {:ok, %Point{x: x, y: y, z: z}}
    else
      _ -> :error
    end
  end

  def str_to_point(point_str) do
    point_str
    |> String.trim()
    |> String.split(",")
    |> do_str_to_point
    |> case do
      :error -> {:error, "Invalid point #{point_str}"}
      {:ok, _} = ok -> ok
    end
  end

  defp str_to_line(line_str) do
    line_str
    |> :binary.split([" ", "\n"], [:global])
    |> Enum.map(&String.trim/1)
    |> extract_many(&str_to_point/1, fn
      "" -> false
      _ -> true
    end)
    |> case do
      {:ok, points} -> {:ok, %Line{points: points}}
      err -> err
    end
  end

  defp extract_many(things, fun, test) do
    things
    |> Enum.reduce_while([], fn thing, acc ->
      if test.(thing) do
        case fun.(thing) do
          {:ok, shape_like} -> {:cont, [shape_like | acc]}
          {:error, _} = e -> {:halt, e}
        end
      else
        {:cont, acc}
      end
    end)
    |> case do
      {:error, _} = e -> e
      shapes -> {:ok, Enum.reverse(shapes)}
    end
  end

  defmodule State do
    defstruct [
      :receiver,
      :receiver_ref,
      status: :out_kml,
      geom_stack: [],
      placemark: nil,
      stack: [],
      path: [],
      emit: [],
      point_count: 0,
      batch_size: 64
    ]
  end

  defmodule Placemark do
    defstruct attrs: %{}, geoms: []
  end

  def put_attribute(%State{placemark: %Placemark{attrs: attrs} = pm} = s, name, value) do
    %State{s | placemark: %Placemark{pm | attrs: Map.put(attrs, name, value)}}
  end

  def put_error(state, _reason) do
    # TODO: partial error handling?
    state
  end

  def pluck_attribute(attributes, name, value) do
    Enum.find_value(attributes, fn
      {^name, value} -> value
      _ -> nil
    end)
    |> case do
      nil ->
        nil

      chars ->
        key = String.trim(chars)
        value = String.trim(value)

        {key, value}
    end
  end

  def push_event(%State{stack: stack, path: path} = state, {name, attributes}) do
    %State{state | stack: [name | stack], path: [{name, attributes} | path]}
  end

  def pop_event(%State{stack: [_ | stack], path: [_ | path]} = state) do
    %State{state | stack: stack, path: path}
  end

  def push_geom(%State{geom_stack: gs} = state, geom) do
    %State{state | geom_stack: [geom | gs]}
  end

  def pop_geom(%State{geom_stack: [geom | []]} = state, _) do
    %State{state | geom_stack: [], placemark: merge_up(geom, state.placemark)}
  end

  def pop_geom(%State{geom_stack: [child, parent | rest]} = state, kind) do
    %State{state | geom_stack: [merge_up(child, parent, kind) | rest]}
  end

  def pop_geom(_state, kind) do
    throw("Cannot pop #{kind}")
  end

  def pop_geom(state), do: pop_geom(state, nil)

  def put_in_placemark(%Placemark{geoms: geoms} = pm, geom) do
    %Placemark{pm | geoms: [geom | geoms]}
  end

  defp merge_up(%Point{} = geom, %Placemark{} = p), do: put_in_placemark(p, geom)
  defp merge_up(%Line{} = geom, %Placemark{} = p), do: put_in_placemark(p, geom)
  defp merge_up(%Polygon{} = geom, %Placemark{} = p), do: put_in_placemark(p, geom)

  defp merge_up(%Multigeometry{} = mp, %Placemark{} = p) do
    put_in_placemark(p, %Multigeometry{geoms: Enum.reverse(mp.geoms)})
  end

  defp merge_up(%Line{} = line, %Polygon{} = poly, :outer_boundary) do
    %Polygon{poly | outer_boundary: line}
  end

  defp merge_up(%Line{} = line, %Polygon{} = poly, :inner_boundaries) do
    %Polygon{poly | inner_boundaries: [line | poly.inner_boundaries]}
  end

  defp merge_up(single, %Multigeometry{} = mg, _) do
    %Multigeometry{geoms: [single | mg.geoms]}
  end

  defp merge_up(child, parent, _) do
    throw("No merge_up impl #{inspect(child)} #{inspect(parent)}")
  end

  def put_point(%State{} = state, text) do
    case str_to_point(text) do
      {:ok, point} -> push_geom(state, point)
      {:error, reason} -> put_error(state, reason)
    end
  end

  def put_line(%State{} = state, text) do
    case str_to_line(text) do
      {:ok, line} -> push_geom(state, line)
      {:error, reason} -> put_error(state, reason)
    end
  end

  textof "ExtendedData/SchemaData/SimpleData", state do
    %State{path: [{_, attributes} | _]} = state
    {name, value} = pluck_attribute(attributes, "name", text)

    put_attribute(state, name, value)
  end

  textof "ExtendedData/Data/value", state do
    %State{path: [_, {_, attributes} | _]} = state
    {name, value} = pluck_attribute(attributes, "name", text)

    put_attribute(state, name, value)
  end

  textof("Point/coordinates", state, do: put_point(state, text))
  textof("MultiGeometry/Point/coordinates", state, do: put_point(state, text))

  textof("LineString/coordinates", state, do: put_line(state, text))
  textof("MultiGeometry/LineString/coordinates", state, do: put_line(state, text))

  textof("Polygon/outerBoundaryIs/LinearRing/coordinates", state, do: put_line(state, text))
  textof("Polygon/innerBoundaryIs/LinearRing/coordinates", state, do: put_line(state, text))

  textof("MultiGeometry/Polygon/outerBoundaryIs/LinearRing/coordinates", state,
    do: put_line(state, text)
  )

  textof("MultiGeometry/Polygon/innerBoundaryIs/LinearRing/coordinates", state,
    do: put_line(state, text)
  )

  textof("name", state, do: put_attribute(state, "name", text))
  textof("description", state, do: put_attribute(state, "description", text))

  textof("TimeSpan/begin", state, do: put_attribute(state, "timespan_begin", text))
  textof("TimeSpan/end", state, do: put_attribute(state, "timespan_end", text))

  on_exit("Point", state, do: state |> pop_geom |> pop_event)
  on_exit("LineString", state, do: state |> pop_geom |> pop_event)
  on_exit("Polygon", state, do: state |> pop_geom |> pop_event)

  on_exit "LinearRing", state do
    boundary_type =
      case state.path do
        [_, {"innerBoundaryIs", _} | _] -> :inner_boundaries
        [_, {"outerBoundaryIs", _} | _] -> :outer_boundary
      end

    state
    |> pop_geom(boundary_type)
    |> pop_event
  end

  on_exit("MultiGeometry", state, do: state |> pop_geom |> pop_event)

  on_enter "Polygon", event, %State{placemark: %Placemark{}} = state do
    state
    |> push_geom(%Polygon{})
    |> push_event(event)
  end

  on_enter "MultiGeometry", event, state do
    state
    |> push_geom(%Multigeometry{})
    |> push_event(event)
  end

  # Push the element name onto the stack, as well as the attributes onto the path
  on_enter _name, event, %State{placemark: %Placemark{}} = state do
    push_event(state, event)
  end

  # Pop the element name off the stack, and pop the attributes as well
  on_exit name, %{placemark: %Placemark{}, stack: [name | stack], path: [_ | path]} = state do
    %State{state | stack: stack, path: path}
  end

  on_enter "Placemark", _, %{placemark: nil} = state do
    %State{state | stack: [], path: [], placemark: %Placemark{}}
  end

  on_exit "Placemark", %{placemark: %Placemark{}} = state do
    %{emit(state) | stack: [], path: [], placemark: nil}
  end

  on_enter("kml", _, state, do: %State{state | status: :kml})
  on_exit("kml", state, do: %State{state | status: :out_kml})

  def handle_event(
        :end_document,
        _event,
        %State{status: :out_kml, receiver: r, receiver_ref: ref} = state
      ) do
    new_state = flush(state)
    send(r, {:done, ref})
    {:ok, new_state}
  end

  def handle_event(:end_document, event, %State{status: :kml}) do
    {:stop, {:error, event}}
  end

  def handle_event(_event, _args, state) do
    {:ok, state}
  end

  defp flush(%State{receiver: r, receiver_ref: ref, emit: emit} = state) do
    send(r, {:placemarks, ref, self(), Enum.reverse(emit)})
    %State{state | emit: []}
  end

  defp await_ack(%State{receiver_ref: ref} = state) do
    receive do
      {:ack, ^ref} -> :ok
    end

    state
  end

  def emit(%State{batch_size: batch_size} = state) do
    case %State{state | emit: [state.placemark | state.emit]} do
      %State{emit: emit} = new_state when length(emit) > batch_size ->
        new_state |> flush |> await_ack

      new_state ->
        new_state
    end
  end

  def stage(binstream, chunk_size \\ 4096) do
    Exkml.Stage.start_link(binstream, chunk_size)
  end

  @doc """
  Get a stream of placemarks
  """
  def stream!(binstream, _chunk_size \\ 4096) do
    ref = events!(binstream)

    Stream.resource(
      fn -> :ok end,
      fn state ->
        receive do
          {:placemarks, ^ref, from, pms} ->
            ack(from, ref)
            {pms, state}

          {:done, ^ref} ->
            {:halt, state}

          {:error, ^ref, event} ->
            raise KMLParseError, message: "Document ended prematurely", event: event
        end
      end,
      fn _ -> :ok end
    )
  end

  @doc """
  Get events sent directly to the calling process

  Returns a unique reference you can use to match on,
  ref = events!(kml_byte_stream)

  Event will be one of
  `{:placemarks, ^ref, from, placemarks}`
    Where placemarks are a list of marks

    When you have done what you need to do, send an acknowledgement.
    The ack contains the ref `ref`, and is a message
    back to the `from` process to make it start parsing the next
    batch

    Like this
    ```
    Exkml.ack(from, ref)
    ```

  `{:done, ^ref}`
    When parsing is done
  `{:error, ^ref, ^pid, event}`
    An error with event being the last SAX event

  """
  def events!(binstream, _chunk_size \\ 4096) do
    me = self()
    ref = make_ref()

    spawn_link(fn ->
      Saxy.parse_stream(binstream, __MODULE__, %State{
        receiver: me,
        receiver_ref: ref
      })
      |> case do
        {:ok, _} ->
          :ok

        {:error, event} ->
          send(me, {:error, ref, event})
      end
    end)

    ref
  end

  def ack(nil, _), do: :ok
  def ack(from, ref), do: send(from, {:ack, ref})
end
