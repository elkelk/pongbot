defmodule Pongbot do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    slack_token = Application.get_env(:pongbot, Pongbot.Slack)[:token]

    # Define workers and child supervisors to be supervised
    children = [
       worker(Pongbot.Slack, [slack_token]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Pongbot.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
