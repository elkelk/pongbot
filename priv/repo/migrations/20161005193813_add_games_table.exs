defmodule Pongbot.Repo.Migrations.AddGamesTable do
  use Ecto.Migration

  def change do
    create table(:games) do
      add :winner, :string, null: false
      add :loser, :string, null: false
      add :season, :string, null: false

      timestamps()
    end
  end
end
