defmodule Minarai do
  @moduledoc """
  Starter application using the Scenic framework.
  """

  def start(_type, args) do
    # IO.puts("minarai.ex: #{inspect(System.argv())}")
    # load the viewport configuration from config
    # :erlang.system_flag(:fullsweep_after, 0) 
    main_viewport_config = Application.get_env(:minarai, :viewport)
    # IO.puts("main_viewport_config = #{inspect(main_viewport_config)}")

    # start the application with the viewport
    children = [
      {Scenic, viewports: [main_viewport_config]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
