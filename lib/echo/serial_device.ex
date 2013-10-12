defmodule Echo.SerialDevice do

  @moduledoc """
  Manages a single serial port

  TODO:   Add buffering/line disicpline
  """

  use Echo.Agent
  alias :serial, as: SerialDriver

  defrecord State, 
    mux: nil, key: nil, state: nil, driver: nil, lt_in: nil, lt_out: nil, 
    b_in: 0, b_out: 0, ip_port: nil, linebuf: <<>>

  @max_linebuf 255
  
  def init(args) do
    key = Dict.get args, :key
    mux = Dict.get args, :mux, nil
    file = key_to_file(key)
    Log.info "Starting SerialDriver for device #{key} on file #{file}"
    driver = SerialDriver.start speed: 4800, open: file
    pt = Echo.service_pt(key)
    Hub.master pt
    Hub.put pt, unix_device: file, status: "online", speed: 4800, 
                type: "serial", label: key_to_label(key)
    {:ok, State.new key: key, state: :idle, driver: driver, mux: mux}
  end

  def _request(path, changes, _context, _from, _state) do
    Log.info "Request to update #{path} with changes #{changes} received"
  end

  ######################### path/key/file conversion #######################

  def key_to_file(key),   do: "/dev/#{key}"
  def file_to_key(file),  do: Path.basename(file)

  def key_to_label(key) do
    case key do
      <<"ttyUSB"::binary, n::binary>> -> "NMEA#{n}"
      <<"cu."::binary, s::binary>> -> s
      other -> other
    end
  end

  @doc "Starts agent instance on the specified device file unless started"
  def ensure_started(args) do
    key = args |> Dict.get :key
    unless started?(key) do
      {:ok, _} = start args
    end
  end

  @doc "Is the port with specified key currently managed (agent started)?"
  def started?(key) do
    Hub.agent(Echo.service_pt(key)) != nil
  end

  def handle_info({:data, data}, state) do
    state = if size(state.linebuf) + size(data) <= @max_linebuf do
      state.update_linebuf &(&1 <> data)
    else
      state
    end
    if String.last(state.linebuf) === "\n" do
      Enum.each String.split(state.linebuf, "\r\n"), fn(s) ->
        if size(s) > 0 do
          :gen_server.cast state.mux, { :cast, state.key, (s <> "\r\n") }
        end
      end
      {:noreply, state.linebuf(<<>>)}
    else
      {:noreply, state}
    end
  end

  # general debug message
  def handle_info(message, state) do
    Log.info "#{__MODULE__}#{state.key} got: #{inspect message}"
    {:noreply, state}
  end

end

