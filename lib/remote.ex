defmodule Remote do
  
  use Application.Behaviour

  @doc "Starts up all core NEMO services as well as supervisors"
  def start(_type, _args) do
    
    # get the hub started and setup a version lock value for this hub
    {:ok, _} = Hub.start
    Hub.put [:sys, :info], vlock: :uuid.generate

    # start basic services - configuration, ssdp, http sever
    {:ok, _} = :config.start
    {:ok, _} = Remote.RootAgent.start
    {:ok, _} = Echo.HttpServer.start 

    Echo.Supervisor.start_link
  end
    
end
    
