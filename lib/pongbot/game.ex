defmodule Pongbot.Game do
  use Ecto.Schema

  schema "games" do
    field :winner
    field :loser
    field :season
    timestamps
  end
end
