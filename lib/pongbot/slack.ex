defmodule Pongbot.Slack do
  use Slack
  import Ecto.Query
  alias Pongbot.Game
  alias Pongbot.Repo

  def handle_connect(slack) do
    IO.puts "Connected as #{slack.me.name}"
  end

  def handle_message(message = %{type: "message"}, slack) do
    if Regex.run ~r/<@#{slack.me.id}>:?\sping/, message.text do
      send_message("<@#{message.user}> pong", message.channel, slack)
    end
    {:ok}
  end
  def handle_message(_,_), do: :ok

  def handle_info({:message, text, channel}, slack) do
    IO.puts "Sending your message, captain!"

    send_message(text, channel, slack)

    {:ok}
  end
  def handle_info(_, _), do: :ok
end
