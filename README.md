# Pongbot
A slack bot written in elixir for keeping track of scores

![pongbot in action](https://dl.dropboxusercontent.com/spa/10hrj3hkmkbc5iz/_x4mb8lu.png "Pongbot in action")


## Installation
- Clone the repository
- Create a slack integration bot by visiting https://your-co.slack.com/apps/manage/custom-integrations
- Create a .env file with the following (or export the variables
  manually):

```bash
export SLACK_TOKEN=<copy your slack bot key here>
export PONGBOT_DB_DATABASE=pongbot_dev
export PONGBOT_DB_USERNAME=postgres
export PONGBOT_DB_PASSWORD=postgres
export PONGBOT_DB_HOST=localhost
export PONGBOT_DB_PORT=5432
```
- Run `source .env` to get the variables in the current shell session
- Install dependencies: `mix deps.get`
- Create the database: `mix ecto.create`
- Migrate the database: `mix ecto.migrate`
- Start the server: `iex -S mix`

## Commands

Pongbot currently considers each month a new season. Once your bot is
registered and the server is running type `@pongbot help` (assuming
you named it pongbot) to see the available options:

- `@pongbot ping`: check if I'm online
- `@pongbot standings`: see the current season standings
- `@pongbot scores`: see all of the scores for the current season
- `@pongbot <a player> vs <another player>`: see the number of wins for the current season
- `@pongbot <a player> beat <another player>`: record a win for the current season
