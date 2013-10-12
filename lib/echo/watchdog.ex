defmodule Echo.Watchdog do

  @moduledoc """

  Implements a watchdog that can help processes handle various
  aspects of unreliable states.

  Super-Simple Setup:

      Watchdog.start :foo, 10000  # start 'foo' watchdog for ten seconds
      Watchdog.alive :foo         # call this at least every < 10 secs

      you get sent {:watchdog, :foo} if you miss a keepalive call

  Multiple Watchdogs:

      Watchdog.start :foo, 10000  # 10 secs
      Watchdog.start :bar, 500    # 500 ms

      Watchdog.alive :foo       # call at least every 10 secs
      Watchdog.alive :bar       # call at least every 500 ms

      {:watchdog, :bar}     # if you miss the bar keepalive 
  
  NOTE:

  Implemented using the erlang process dictionary, which some will consider
  evil.  I'm not sure why in this case, it seems like the cleanest solution
  to allow a scope of timer names to be set on a process.
  
  """

  @doc """ 
  start(id, timeout_msec)

  Setup a watchdog timer which sends {:watchdog, id} after timeout_msec 
  milliseconds, unless alive(id) is called, which resets it for another 
  timeout_msec.
  """
  def start(id, msec) do
    timer_ref = :erlang.send_after(msec, self, {:watchdog, id})
    Process.put {:watchdog, id}, {timer_ref, msec}
    timer_ref
  end

  @doc "combination start & alive"
  def alive(id, msec) do
    case Process.get {:watchdog, id} do
      {timer_ref, msec} ->
        :erlang.cancel_timer(timer_ref)
      other -> other
    end
    start(id, msec)
  end 

  @doc "Reset a watchdog timer, giving another time period" 
  def alive(id) do
    case Process.get {:watchdog, id} do
      {timer_ref, msec} ->
        :erlang.cancel_timer(timer_ref)
        start(id, msec)
      other -> other
    end
  end 


end

