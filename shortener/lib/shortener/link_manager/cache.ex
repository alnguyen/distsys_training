defmodule Shortener.LinkManager.Cache do
  @moduledoc false
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def lookup(_cache \\ __MODULE__, key) do
    case :ets.lookup(:links, key) do
      [] ->
        {:error, :not_found}

      [{^key, url} | _] ->
        {:ok, url}

      _ ->
        {:error, :not_found}
    end
  end

  def insert(cache \\ __MODULE__, key, value) do
    GenServer.call(cache, {:insert, key, value})
  end

  def broadcast_insert(cache \\ __MODULE__, key, value) do
    GenServer.abcast(Node.list(), cache, {:insert, key, value})
  end

  def flush(cache \\ __MODULE__) do
    GenServer.call(cache, :flush)
  end

  def init(_args) do
    {:ok, %{table: :ets.new(:links, [:named_table])}}
  end

  def handle_cast({:insert, key, value}, data) do
    :ets.insert(data.table, {key, value})
    {:noreply, data}
  end

  def handle_call({:insert, key, value}, _from, data) do
    :ets.insert(data.table, {key, value})
    {:reply, :ok, data}
  end

  def handle_call(:flush, _from, data) do
    :ets.delete_all_objects(data.table)
    {:reply, :ok, data}
  end
end
