defmodule Hub do

  @proc_path_key {:agent, :path}

  @moduledoc """
  Stub for an Elixir rewite of Echo's Hub (formerly written in Erlang).
  For now, delegates mainly to the Erlang implementation, but adds some
  new features, and changes the semantics of how the hub is used slightly,
  so new code can begin to use a newer style Hub API.
  """

  require Lager
  
  def start do
    :hub.start
  end
  
  @doc """
  Associate the currrent process as the primary agent for the given 
  path.  This binds/configures this process to the hub, and also sets
  the path as the "agent path" in the process dictionary
  """
  def master(path) do
    Process.put @proc_path_key, path
    :hub.master(path)
  end

  def put(path, keys_and_values) do
    update(path, keys_and_values)
  end

  def update(path, keys_and_values, opts // []) do
    :hub.update(path, keys_and_values, opts)
  end

  def get(path, key) do
    Dict.get :hub.fetch(path), key
  end
  
  def fetch(path // []) do
    :hub.fetch(path)
  end

  @doc "Returns the controlling agent for this path, or nil if none"
  def agent(path) do 
    case :hub.manager(path) do
      {:ok, {pid, _opts} } -> pid
      _ -> nil
    end
  end

end

