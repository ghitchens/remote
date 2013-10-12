defmodule Echo.TcpTee do

  @moduledoc """
  TcpTee provides a simple way to make a connection to a tcp port
  in one place and repeat it somewhere else.
  
  It opens a socket to a remote host/port, and then repeats that socket
  to as many listeners on the same port on the local system
  """
  @agent_point_base [ :services ]

  use Echo.Agent
  
  defrecord State, key: nil, host: nil, socket: nil, port: nil, 
            upstream_port: nil, 
            opts: [close_clients: false, auto_upstream: false],
            clients: []

  def init(args) do
    Log.info "Starting TcpTee (#{inspect args})"    
    key  = Dict.get args, :key
    Hub.master point(key)
    
#    opts = Dict.get args, :opts, []
    port = Dict.get args, :port
    upstream_port = Dict.get args, :upstream_port, port
    host = Dict.get args, :host
    
    {:ok, _} = :ranch.start_listener(key, 4, :ranch_tcp, [port: port], 
                                    Echo.TcpTee.Protocol, [tee: self] )
    Hub.update point(key), type: "tcp_repeater", port: port, upstream_port: upstream_port
    state = State.new host: host, key: key, port: port, upstream_port: upstream_port, opts: args
    {:ok, state}
  end

  def terminate(reason, state) do
    Log.info "Stopping TcpTee #{state.key}, reason: #{inspect reason}"
    :gen_udp.close(state.socket)
  end

  defp point(key), do: @agent_point_base ++ [key]

  # one of our clients asked us to send some data on to the server, so 
  # forward it to our server socket
  def handle_cast({:send, data}, state) do
    if (state.socket) do
      :ok = :gen_tcp.send state.socket, data
    end
    {:noreply, state}
  end        

  # close an upstream server connection manually.  Closes all clients if
  # option :close_clients is true
  def handle_call({:close_upstream, reason}, _from, state) do
    if (state.socket != nil) do
      :ok = :gen_tcp.close(state.socket)
      Log.info "#{__MODULE__}: upstream tcp closed due to #{inspect reason}"
    end
    if Dict.get(state.opts, :close_clients) do
      Enum.each state.clients, fn(client) ->
        :ok = :gen_server.cast(client, {:close})
      end    
      state = state.clients(nil)
    end
    {:reply, {:ok, :closed}, state.socket(nil)}
  end

  # open the upstream server manually.  
  # fails silently if auto_upstream option is set
  def handle_call({:open_upstream, reason}, _from, state) do
    Log.info "#{__MODULE__} (#{state.key}) asked to open due to #{inspect reason}"
    unless state.opts |> Dict.get :auto_upstream do
      unless state.socket do
        invoke_callback(:before_open, state)
        {:ok, socket} = :gen_tcp.connect state.host, state.upstream_port, [
                                  :binary, {:active, true}]
        state = state.socket(socket)
      end
    end
    {:reply, {:ok, :opened}, state }
  end        

  # a client connected, connect to the server if we're the first one
  # and auto_upstream is set
  def handle_call({:add_client, client}, _from, state) do
    Log.info "#{__MODULE__} (#{state.key}) client connected: #{inspect client}"
    if Dict.get(state.opts, :auto_upstream) do
      unless state.socket do
        invoke_callback(:before_open, state)
        {:ok, socket} = :gen_tcp.connect state.host, state.port, [
                                  :binary, {:active, true}]
        state = state.socket(socket)
      end
    end
    {:reply, :connected, state.update_clients &(&1 ++ [client]) }
  end        

  # a client disconnected, disconnect the upstream if it's the last one and auto_upstream
  # is set
  def handle_call({:del_client, client}, _from, state) do
    Log.info "#{__MODULE__} (#{state.key}) client disconnected: #{inspect client}"
    state = state.update_clients &(&1 -- [client])
    # Log.info (inspect state)
    if state.opts |> Dict.get :auto_upstream do
      state = if ((state.socket != nil) and (length(state.clients) == 0)) do
        :ok = :gen_tcp.close(state.socket)
        Log.info "\tlast client disconnected, closed server socket"
        state.socket(nil)
      else
        Log.info "\tother clients connected, keeping socket open"
        state
      end
    end
    {:reply, :disconnected, state }
  end        


  # the server closed the socket, so close all clients
  def handle_info({:tcp_closed, _socket}, state) do
    Log.info "#{__MODULE__} #{state.key} server socket closed"
    if Dict.get(state.opts, :auto_reopen) do
      invoke_callback(:before_open, state)
      {:ok, socket} = :gen_tcp.connect state.host, state.upstream_port, [
                                :binary, {:active, true}]
      invoke_callback(:after_open, state)
      {:noreply, state.socket(socket)}
    else # we aren't supposed to reopen it, so close it
      if Dict.get(state.opts, :close_clients) do
        Enum.each state.clients, fn(client) ->
          :ok = :gen_server.cast(client, {:close})
        end    
      end
      {:noreply, state.socket(nil)}
    end
  end

  # when receive tcp data from the server, repeat it to each of our
  # current client processes by casting a message to them
  def handle_info({:tcp, _socket, data}, state) do
    Log.debug "#{__MODULE__} (#{state.key}) from host: #{data}"
    Enum.each state.clients, fn(client) ->
      Log.debug "#{__MODULE__} (#{state.key}) sending to #{inspect client}"
      :ok = :gen_server.cast(client, {:send, data})
    end    
    {:noreply, state}
  end

  def handle_info(message, state) do
    Log.info "#{__MODULE__}#{state.key}: #{inspect message}"
    {:noreply, state}
  end
  
  defp invoke_callback(callback, state) do
    case Dict.get(state.opts, callback) do
      nil -> nil
        Log.info "#{__MODULE__} #{state.key} couldnt find callback #{callback} in #{inspect state.opts}"
        nil
      f -> 
        Log.info "#{__MODULE__} #{state.key} calling back: #{callback}"
        f.()
    end
  end

  defmodule Protocol do
    
    @behaviour :ranch_protocol  
    use Echo.Agent

    defrecord State, tee: nil, socket: nil, transport: nil

    @doc "callback for Ranch protocol handler"
    def start_link(ref, socket, transport, opts) do
      :proc_lib.start_link(__MODULE__, :init, 
        [ref, socket, transport, opts] )
    end
  
    @doc """
    Called by started process to enable ranch protocl handler 
    to be a gen_server without deadlocks.  see 
    http://ninenines.eu/docs/en/ranch/HEAD/guide/protocols
    """
    def init(ref, socket, transport, opts)  do
      tee = Dict.get opts, :tee 
      :connected = :gen_server.call(tee, {:add_client, self})
      :ok = :proc_lib.init_ack({:ok, self})
      :ok = :ranch.accept_ack(ref)
      :ok = apply(transport, :setopts, [socket, [{:active, true}]])
      state = State.new socket: socket, transport: transport, tee: tee
      :gen_server.enter_loop(__MODULE__, [], state)
    end

    def terminate(_reason, state) do
      :disconnected = :gen_server.call(state.tee, {:del_client, self})
    end

    def handle_cast({:send, data}, state) do
      Log.debug "#{__MODULE__}#: got request to forward data"
      :ok = apply state.transport, :send, [state.socket, data]
      {:noreply, state}
    end
    
    def handle_cast({:close}, state) do
      :ok = apply(state.transport, :close, [state.socket])
      {:noreply, state}
    end

    def handle_info({:tcp, _socket, data}, state) do
      :gen_server.cast state.tee, {:send, data}
      {:noreply, state}
    end

    def handle_info({:tcp_closed, _socket}, state) do
      :disconnected = :gen_server.call(state.tee, {:del_client, self})
      {:noreply, state}
    end
  
  end

end
