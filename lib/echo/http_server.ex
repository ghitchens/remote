defmodule Echo.HttpServer do

  @moduledoc """
  Provides the HTTP server for Echo.   
  Uses the popular Cowboy lightweight/fast HTTP server framework.
  """

  def start do
    
    panel_dir = Path.join [Path.dirname(:code.which(__MODULE__)), "..", "priv", "panel" ]
    upnp_dir = Path.join [Path.dirname(:code.which(__MODULE__)), "..", "priv", "upnp" ]
    mt = {&:mimetypes.path_to_mimes/2, :default}

    dispatch = :cowboy_router.compile([ {:_, [  
        {"/panel/[:...]",:cowboy_static, [directory: panel_dir, mimetypes: mt]},
        {"/upnp/[:...]",:cowboy_static, [directory: upnp_dir, mimetypes: mt]},
        {:_, :jrtp_bridge, []} ]} ])

    http_port = case :hub.fetch [:config, :http_port] do
      {_, :error} -> 8080
      {_, port} -> port
    end

    # setup the version_info string in the cowboy environment
    :cowboy.start_http(:http, 10, [port: http_port], [ env: 
                        [dispatch: dispatch] ])
  end

end

