defmodule Shortener.Cluster do
  @moduledoc """
  This module provides an interface for updating clusters as well as a
  supervision tree for starting and stopping node discovery.
  """

  alias Shortener.Storage

  alias ExHashRing.HashRing

  @ring_key {__MODULE__, :hash_ring}

  def child_spec(_args) do
    children = [
      {Cluster.Supervisor, [topology(), [name: Shortener.ClusterSupervisor]]}
    ]

    %{
      id: __MODULE__,
      type: :supervisor,
      start: {Supervisor, :start_link, [children, [strategy: :one_for_one]]}
    }
  end

  def find_node(key) do
    hash_ring = :persistent_term.get(@ring_key)

    HashRing.find_node(hash_ring, key)
  end

  # Sets the canonical set of nodes into persistent storage.
  def set_canonical_nodes(nodes) do
    bin = :erlang.term_to_binary(nodes)

    :ok = Storage.set("shortener:cluster", bin)
  end

  def update_ring do
    {:ok, bin_nodes} = Storage.get("shortener:cluster")

    nodes = :erlang.binary_to_term(bin_nodes)

    ring = HashRing.new()

    hash_ring =
      Enum.reduce(nodes, ring, fn node, acc ->
        {:ok, updated_ring} = HashRing.add_node(acc, node)
        updated_ring
      end)

    :ok = :persistent_term.put(@ring_key, hash_ring)
  end

  defp topology do
    [
      shortener: [
        strategy: Cluster.Strategy.Gossip
      ]
    ]
  end
end
