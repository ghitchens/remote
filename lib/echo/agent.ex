defmodule Echo.Agent do

  @moduledoc """
  This module defines the standard template for an agent for Echo.
  
  An agent binds to the hub at a single or set of points.
  """

  @doc false
  defmacro __using__(_) do

    quote location: :keep do

      require Lager

      require Hub
      alias Lager, as: Log
      use GenServer.Behaviour    

      @doc false
      def start(state // []) do
        state_inspect = inspect(state, width: 32)
        Lager.info "Starting Agent #{__MODULE__} (#{state_inspect})"
        #:gen_server.start {:local, __MODULE__}, __MODULE__, state, []
        result = :gen_server.start __MODULE__, state, []
        Log.info "  start returns #{inspect result}"
        result
      end

      @doc false
      def start_link(state // []) do 
      #:gen_server.start_link {:local, __MODULE__}, __MODULE__, state, []
        :gen_server.start_link __MODULE__, state, []
      end

      @doc false
      # delegate request calls to the _request function signature
      # def handle_call({:request, path, {:update, changes}, context}, from, state) do
      #  _request(path, changes, context, from, state)

    end
  end

end
