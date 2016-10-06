defmodule Pongbot.Slack do
  use Slack
  import Ecto.Query
  alias Pongbot.Game
  alias Pongbot.Repo

   @message_types [
     {"ping$", :ping},
     {"help$", :help},
     {"standings$", :standings},
     {"@?[A-z,1-9]*\svs\s@?[A-z,1-9]*", :stats},
     {"@?[A-z,1-9]*\sversus\s@?[A-z,1-9]*", :stats},
     {"@?[A-z,1-9]*\sbeats?\s@?[A-z,1-9]*", :record_win},
     {"", :noop},
   ]

  def handle_connect(slack) do
    IO.puts "Connected as #{slack.me.name}"
  end

  def handle_message(message = %{type: "message"}, slack) do
    message |> parse(slack) |> act_on_message(slack)
    {:ok}
  end
  def handle_message(_,_), do: :ok

  def handle_info({:message, text, channel}, slack) do
    IO.puts "Sending your message, captain!"
    send_message(text, channel, slack)
    {:ok}
  end
  def handle_info(_, _), do: :ok

  def parse(message, slack) do
    IO.puts "Received message: #{message.text}"
    {_, type} = Enum.find(@message_types, {nil, :unknown}, fn {reg, type} ->
       String.match?(message.text, ~r/<@#{slack.me.id}>:?\s#{reg}/)
     end)
    {type, message}
  end

  def act_on_message({:ping, message}, slack) do
    send_message("<@#{message.user}> pong", message.channel, slack)
  end
  def act_on_message({:standings, message}, slack) do
    send_message("<@#{message.user}> Ok here are the standings:", message.channel, slack)
    write_standings(standings, message, slack)
  end
  def act_on_message({:record_win, message}, slack) do
    send_message("<@#{message.user}> win recorded.", message.channel, slack)
    {winner, loser} = parse_players(message)
    record_win(winner, loser)
    act_on_message({:stats, message}, slack)
  end
  def act_on_message({:stats, message}, slack) do
    {winner, loser} = parse_players(message)
    send_message("<@#{message.user}> Here are the stats for the #{current_season} season:", message.channel, slack)
    send_message("#{winner} beat #{loser} #{stats(winner, loser)} times", message.channel, slack)
    send_message("#{loser} beat #{winner} #{stats(loser, winner)} times", message.channel, slack)
  end
  def act_on_message({:help, message}, slack) do
    send_message("<@#{message.user}> Here are the options:", message.channel, slack)
    send_message("ping: check if I'm online", message.channel, slack)
    send_message("standings: see the current season standings", message.channel, slack)
    send_message("<a player> vs <another player>: see the number of wins for the current season", message.channel, slack)
    send_message("<a player> beat <another player>: record a win for the current season", message.channel, slack)
  end
  def act_on_message({:noop, message}, slack) do
    send_message("<@#{message.user}> I'm not sure what you want.", message.channel, slack)
  end
  def act_on_message({:unknown, message}, slack) do
  end

  defp write_standings(rows, message, slack) do
    Enum.map(rows, fn(row) ->
      {winner, loser, count} = row
      send_message("#{winner} beat #{loser} #{count} times", message.channel, slack)
    end)
  end

  defp parse_players(message) do
    [_bot | tail] = String.split(message.text, " ")
    [winner | tail] = tail
    [_verb | tail] = tail
    [loser | _tail] = tail
    {String.replace(winner, "@", ""), String.replace(loser, "@", "")}
  end

  defp current_season() do
    {:ok, season} = Timex.format(Timex.today, "{YYYY}-{M}")
    season
  end

  defp record_win(winner, loser) do
    game = %Game{winner: winner, loser: loser, season: current_season}
    Repo.insert(game)
  end

  defp stats(winner, loser) do
    season = current_season()
    Game
    |> select([g], count(g.id))
    |> where([g], winner: ^winner)
    |> where([g], loser: ^loser)
    |> where([g], season: ^season)
    |> Repo.one
  end

  defp standings do
    season = current_season()
    Game
    |> select([g], {g.winner, g.loser, count(g.id)})
    |> group_by([g], [:winner, :loser])
    |> where([g], season: ^season)
    |> Repo.all
  end
end
