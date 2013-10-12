defmodule Remote.Mixfile do
  use Mix.Project

  def project do
    [ app: :remote,
      version: "13.8.1",
      elixir: "~> 0.10.2",
      deps: deps ]
  end

  # Configuration for the OTP application
  def application do
    [
      mod: { Remote, [] },
      applications: [ :lager, :exlager, :cowboy, :'erlang-serial']
    ]
  end

  defp deps do
    [
      { :cowboy, github: "extend/cowboy"}, 
      { :mimetypes, github: "spawngrid/mimetypes" },
      { :jsx, github: "talentdeficit/jsx", compile: "~/.mix/rebar compile" },  
      { :httpotion, github: "myfreeweb/httpotion"},  # for testing for now
      { :'erlang-serial', github: "ghitchens/erlang-serial", 
                          compile: "make && ~/.mix/rebar compile" },
      { :exlager, github: "khia/exlager" }
    ]
  end
end
