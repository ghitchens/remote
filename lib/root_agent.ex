defmodule Remote.RootAgent do

  use Echo.Agent

  def init(_args) do
    Hub.put [:services, :root], 
            label: "Remote Radio", type: :station, status: :online
    {:ok, nil}
  end
  
end


