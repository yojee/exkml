defmodule Exkml.Stage do
  use GenStage

  def start_link(binstream, chunk_size) do
    GenStage.start_link(__MODULE__, [binstream, chunk_size])
  end

  def init([binstream, chunk_size]) do
    ref = Exkml.events!(binstream)
    buf = []
    demand = 0
    {:producer, {:started, ref, buf, demand, nil}}
  end

  def handle_demand(more_demand, {status, ref, buf, demand, from}) do
    new_demand = demand + more_demand
    {emit, keep} = Enum.split(buf, new_demand)
    less_demand = new_demand - length(emit)

    new_state = {status, ref, keep, less_demand, from}

    Exkml.ack(from, ref)

    maybe_end(new_state)

    {:noreply, emit, new_state}
  end

  def handle_info({:placemarks, ref, from, pms}, {status, ref, buf, 0, _}) do
    {:noreply, [], {status, ref, buf ++ pms, 0, from}}
  end

  def handle_info({:placemarks, ref, from, pms}, {status, ref, buf, demand, _}) do
    {emit, keep} = Enum.split(buf ++ pms, demand)
    new_demand = demand - length(emit)
    Exkml.ack(from, ref)

    {:noreply, emit, {status, ref, keep, new_demand, from}}
  end

  def handle_info({:done, ref}, {_, ref, buf, demand, from}) do
    new_state = {:done, ref, buf, demand, from}
    maybe_end(new_state)
    {:noreply, [], new_state}
  end

  def handle_info(:stop, state) do
    {:stop, :normal, state}
  end

  defp maybe_end({:done, _, [], _, _}), do: send(self(), :stop)
  defp maybe_end(_), do: :nope
end
