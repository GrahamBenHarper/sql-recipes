### SQL-Recipes

This shell script contains commands for modifying a sqlite3 database with an emphasis on storing recipe ingredient lists. The available commands are as follows:

 - `add` will guide you through entering a recipe into the database.
 - `dump` will guide you through dumping whatever tables you'd like from the database.
 - `print RECIPE` will print the ingredient list (including quantities) for the recipe named `RECIPE`
 - `search INGREDIENT1 INGREDIENT2` will print all recipes containing both `INGREDIENT1` and `INGREDIENT2` as ingredients, along with the quantity of each ingredient used in each recipe. `search` doesn't support a higher number of ingredients or more complicated logic, but it also works if you search just one ingredient name.

## Dependencies
All commands in the script invoke `sqlite3`. To check if you have `sqlite3` installed, type `which sqlite3`. If you do not have `sqlite3` installed, you can install it via `apt` with
```
  sudo apt-get install sqlite3
```