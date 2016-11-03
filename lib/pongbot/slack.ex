defmodule Pongbot.Slack do
  use Slack
  import Ecto.Query
  alias Pongbot.Game
  alias Pongbot.Repo

   @message_types [
     {"ping$", :ping},
     {"help$", :help},
     {"challenge\s[A-z,1-9]*$", :challenge},
     {"scores$", :all_scores},
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
    {_, type} = Enum.find(@message_types, {nil, :unknown}, fn {reg, _type} ->
       String.match?(message.text, ~r/<@#{slack.me.id}>:?\s#{reg}/)
     end)
    {type, message}
  end

  def act_on_message({:ping, message}, slack) do
    send_message("<@#{message.user}> pong", message.channel, slack)
  end
  def act_on_message({:challenge, message}, slack) do
    name = String.replace(message.text, ~r/.*challenge\s/, "")
    send_message("<@#{message.user}> has challenged #{name}", message.channel, slack)
    send_message("#{name}, do you accept this challenge?", message.channel, slack)
  end
  def act_on_message({:all_scores, message}, slack) do
    send_message("<@#{message.user}> Ok here are the scores for this season:", message.channel, slack)
    write_scores(standings, message, slack)
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
    send_message("scores: see all of the scores for the current season", message.channel, slack)
    send_message("challenge <a player>: initiate a challenge", message.channel, slack)
    send_message("<a player> vs <another player>: see the number of wins for the current season", message.channel, slack)
    send_message("<a player> beat <another player>: record a win for the current season", message.channel, slack)
  end
  def act_on_message({:noop, message}, slack) do
    send_message("<@#{message.user}> I'm not sure what you want.", message.channel, slack)
  end
  def act_on_message({:unknown, _message}, _slack) do
  end

  defp write_scores(rows, message, slack) do
    summary = process_score_rows(rows, %{})

    Enum.each(summary, fn({key, player_set}) ->
      text = Enum.reduce(player_set, key, fn ({key, val}, acc) ->
        "#{acc} <#{key} #{val}> "
      end)
      send_message(text, message.channel, slack)
    end)
  end

  defp process_score_rows([], summary) do
    summary
  end
  defp process_score_rows(rows, summary) do
    [row | tail] = rows
    summary = merge_score(row, summary)
    process_score_rows(tail, summary)
  end

  defp merge_score({winner, loser, count}, summary) do
    sorted = Enum.sort([winner, loser])
    key = Enum.join(sorted, " vs ")
    current_set = summary[key]
    summary = Map.put(summary, key, current_set || %{})
    new_set = Map.put(summary[key], winner, count)
    Map.put(summary, key, new_set)
  end

  defp write_standings(rows, message, slack) do
    summary = process_score_rows(rows, %{})
    standings = parse_standings(summary)
    text = Enum.reduce(standings, "", fn ({key, val}, acc) ->
      "#{acc} | #{key}: #{val}"
    end)
    send_message(text, message.channel, slack)
  end

  defp parse_standings(summary) do
    minimum_threshhold = 5
    Enum.reduce(summary, %{}, fn({_key, player_set}, acc) ->
      case Map.keys(player_set) do
        [player1, player2] ->
          number_of_games = player_set[player1] + player_set[player2]
          cond do
            number_of_games < minimum_threshhold ->
              acc
            player_set[player1] > player_set[player2] ->
              current_value = acc[player1] || 0
              Map.put(acc, player1, current_value + 1)
            player_set[player1] < player_set[player2] ->
              current_value = acc[player2] || 0
              Map.put(acc, player2, current_value + 1)
            true ->
              acc
          end
        [player1] ->
          cond do
            player_set[player1] >= minimum_threshhold ->
              current_value = acc[player1] || 0
              Map.put(acc, player1, current_value + 1)
            true ->
              acc
          end
        _ ->
          acc
      end
    end)
  end

  defp parse_players(message) do
    [_bot | tail] = String.split(message.text, " ")
    [winner | tail] = tail
    [_verb | tail] = tail
    [loser | _tail] = tail
    {clean_name(winner), clean_name(loser)}
  end

  defp clean_name(name) do
    name
    |> String.replace("@", "")
    |> String.downcase()
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
