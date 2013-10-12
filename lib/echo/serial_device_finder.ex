defmodule Echo.SerialDeviceFinder do

  use Echo.Agent

  @moduledoc """
  Repeatedly scans for new any new serial port devices added to the
  system, and starts a Echo.SerialDevice Agent when they are found.
  """
  
  @device_pattern   "/dev/{cu.*,ttyUSB*,ttyS*}"
  @poll_period      1000                          # once a second
  
  def init(state) do
    poll_device_files_and_repeat(state)
    {:ok, state}
  end

  defp poll_device_files_and_repeat(state) do
    Log.debug "polling all serial device files"
    Enum.map Path.wildcard(@device_pattern), fn(f) ->
      args = Dict.put state, :key, Echo.SerialDevice.file_to_key(f)
      Echo.SerialDevice.ensure_started(args) 
    end
    Log.debug "retriggering timer for port repoll"
    :erlang.send_after @poll_period, Kernel.self, :poll_trigger
  end

  def handle_info(:poll_trigger, state) do
    poll_device_files_and_repeat(state)
    {:noreply, state}
  end

  def _request(path, changes, _context, _from, _state) do
    Log.info "Request to update #{path} with changes #{changes} received"
  end

end
