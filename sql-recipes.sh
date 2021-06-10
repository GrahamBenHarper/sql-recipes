#!/bin/bash

DATABASE_FILE="recipes.db"

# Removes all punctuation from the
# input variable and echoes it
sanitize() {
  echo "$1" | tr -d [:punct:]
}

# Initializes an empty database with the required tables if none exists
init_database() {
  if [ -f "${DATABASE_FILE}" ]; then
    echo "--Recipe database ${DATABASE_FILE} found!"
  else
    echo "--Recipes database not detected! Creating ${DATABASE_FILE}..."
    sqlite3 ${DATABASE_FILE} "CREATE TABLE ingredientIds (id NOT NULL, name NOT NULL);"
    sqlite3 ${DATABASE_FILE} "CREATE TABLE recipeIds (id NOT NULL, name NOT NULL);"
    sqlite3 ${DATABASE_FILE} "CREATE TABLE recipes (recipeId NOT NULL, ingredientId NOT NULL, amount NOT NULL);"
  fi
}

# Performs some checks to make sure DATABASE_FILE
# has the correct tables and the tables have the correct columns
check_database() {
  TEST1=$(sqlite3 ${DATABASE_FILE} "SELECT * FROM recipes WHERE recipeId=0 AND ingredientId=0 AND amount=0")
  if [ $? != 0 ]; then
    echo "!!Recipe database is formatted incorrectly! Aborting..."
    exit 1
  fi
  
  TEST2=$(sqlite3 ${DATABASE_FILE} "SELECT * FROM recipeIds WHERE id=0 AND name=0")
  if [ $? != 0 ]; then
    echo "!!Recipe database is formatted incorrectly! Aborting..."
    exit 1
  fi

  TEST3=$(sqlite3 ${DATABASE_FILE} "SELECT * FROM ingredientIds WHERE id=0 AND name=0")
  if [ $? != 0 ]; then
    echo "!!Recipe database is formatted incorrectly! Aborting..."
    exit 1
  fi

  echo "--Recipe database ${DATABASE_FILE} is formatted correctly!"
}

# Prompts the user for a table name and
# executes a dump with the user's argument
dump_database() {
  read -p 'Enter the recipe table to dump (enter nothing to dump all): ' TABLE_NAME
  TABLE_NAME=$(sanitize "${TABLE_NAME}")
  sqlite3 ${DATABASE_FILE} ".dump ${TABLE_NAME}"
}

# Attempts to add a recipe name to the table, and if the
# name is already in the table, the table is not modified.
# Returns the recipe's ID.
add_recipe_name() {
  if [ $# -ne 1 ]; then
    echo "!!No recipe name to add! Aborting..."
    return 0
  fi

  MY_ID=$(sqlite3 ${DATABASE_FILE} "SELECT id FROM recipeIds WHERE name='$1'")
  if [[ ${MY_ID} == "" ]]; then
    # Grab the highest ID entry in the table and add 1. This purposely ignores the case where rows are deleted from the table.
    LAST_ID=$(sqlite3 ${DATABASE_FILE} "SELECT MAX(id) FROM recipeIds")
    if [[ ${LAST_ID} == "" ]]; then
      MY_ID=1
    else
      MY_ID=$(($LAST_ID + 1))
    fi
    echo "--Inserting recipe name \"$1\" into recipe names table at position ${MY_ID}..."
    sqlite3 ${DATABASE_FILE} "INSERT INTO recipeIds(id, name) VALUES(${MY_ID},'$1')"
  else
    echo "--Name found for $1 in recipes table!"
  fi
  return ${MY_ID}
}

# Attempts to add an ingredient name to the table, and
# if the name is already in the table, the table is not modified.
# Returns the ingredient's ID.
add_ingredient_name() {
  if [ $# -ne 1 ]; then
    echo "!!No ingredient name to add! Aborting..."
    return 0
  fi

  MY_ID=$(sqlite3 ${DATABASE_FILE} "SELECT id FROM ingredientIds WHERE name='$1'")
  if [[ ${MY_ID} == "" ]]; then
    # Grab the highest ID entry in the table and add 1. This purposely ignores the case where rows are deleted from the table.
    LAST_ID=$(sqlite3 ${DATABASE_FILE} "SELECT MAX(id) FROM ingredientIds")
    if [[ ${LAST_ID} == "" ]]; then
      MY_ID=1
    else
      MY_ID=$(($LAST_ID + 1))
    fi
    echo "--Inserting ingredient name \"$1\" into recipe names table at position ${MY_ID}..."
    sqlite3 ${DATABASE_FILE} "INSERT INTO ingredientIds(id, name) VALUES(${MY_ID},'$1')"
  else
    echo "--Name found for $1 in recipes table!"
  fi  
  return ${MY_ID}
}

# Adds a recipe to the database.
# It prompts the user for a recipe name
# and then prompts for ingredients and amounts
# repeatedly until the user is finished.
add_recipe() {
  read -p 'Enter the recipe name: ' RECIPE
  RECIPE=$(sanitize "${RECIPE}")    
  add_recipe_name "$RECIPE"
  RECIPE_ID=$?

  MORE_INGREDIENTS=1
  while [ ${MORE_INGREDIENTS} == 1 ]; do
    read -p 'Enter an ingredient name: ' INGREDIENT
    INGREDIENT=$(sanitize "${INGREDIENT}")      
    INGREDIENTS+=("${INGREDIENT}")
    read -p 'Enter the amount of ingredient: ' INGREDIENT_AMOUNT
    # TODO: sanitizing this removes decimals and fractions. We'll revisit this later...
    # INGREDIENT_AMOUNT=$(sanitize "${INGREDIENT_AMOUNT}")
    INGREDIENT_AMOUNTS+=("${INGREDIENT_AMOUNT}")
    
    ISNT_VALID=1
    while [ ${ISNT_VALID} == 1 ]; do
      read -p 'Enter another ingredient? (y)es/(n)o/(c)ancel: ' ENTER_ANOTHER	  
      if [[ ${ENTER_ANOTHER} == "y" ]] || [[ ${ENTER_ANOTHER} == "yes" ]]; then
        ISNT_VALID=0
      fi

      if [[ ${ENTER_ANOTHER} == "n" ]] || [[ ${ENTER_ANOTHER} == "no" ]]; then
        ISNT_VALID=0
	MORE_INGREDIENTS=0
      fi

      if [[ ${ENTER_ANOTHER} == "c" ]] || [[ ${ENTER_ANOTHER} == "cancel" ]]; then
        exit 1
      fi
    done
  done

  for ((i=0; i<${#INGREDIENTS[@]}; i++ )); do
    add_ingredient_name "${INGREDIENTS[$i]}"
    INGREDIENT_ID=$?
    sqlite3 ${DATABASE_FILE} "INSERT INTO recipes(recipeId, ingredientId, amount) VALUES(${RECIPE_ID},${INGREDIENT_ID},'${INGREDIENT_AMOUNTS[$i]}')"
  done
}

# Outputs all recipe names associated with two ingredients.
dual_search_recipes() {
  if [ $# -le 1 ]; then
    echo "!!Not enough ingredients provided for dual search!"
    return 1
  fi

  QUERY1=$(echo $1 | tr "*" "%")
  QUERY2=$(echo $2 | tr "*" "%")

  RESULT=$(sqlite3 ${DATABASE_FILE} "SELECT DISTINCT recipeIds.name, recipes.amount, recipes2.amount FROM recipeIds INNER JOIN recipes ON recipeIds.id=recipes.recipeId INNER JOIN recipes AS 'recipes2' ON recipes.recipeId=recipes2.recipeId INNER JOIN ingredientIds ON ingredientIds.id=recipes.ingredientId AND ingredientIds.name LIKE '${QUERY1}' INNER JOIN ingredientIds AS 'ingredientIds2' ON ingredientIds2.id=recipes2.ingredientId AND ingredientIds2.name LIKE '${QUERY2}'")
  if [[ ${RESULT} == "" ]]; then
    echo "!!No recipes found with ingredients ${QUERY1} and ${QUERY2}!"
    return 1
  fi
  sqlite3 ${DATABASE_FILE} "SELECT DISTINCT recipeIds.name, recipes.amount, recipes2.amount FROM recipeIds INNER JOIN recipes ON recipeIds.id=recipes.recipeId INNER JOIN recipes AS 'recipes2' ON recipes.recipeId=recipes2.recipeId INNER JOIN ingredientIds ON ingredientIds.id=recipes.ingredientId AND ingredientIds.name LIKE '${QUERY1}' INNER JOIN ingredientIds AS 'ingredientIds2' ON ingredientIds2.id=recipes2.ingredientId AND ingredientIds2.name LIKE '${QUERY2}'"
}

# Outputs all recipe names associated with a given ingredient name.
search_recipes() {
  if [ $# -eq 0 ]; then
    echo "!!No ingredient name specified to search!"
    return 1
  fi

  QUERY=$(echo $1 | tr "*" "%")

  RESULT=$(sqlite3 ${DATABASE_FILE} "SELECT DISTINCT recipeIds.name, recipes.amount FROM recipeIds INNER JOIN recipes ON recipeIds.id=recipes.recipeId INNER JOIN ingredientIds ON ingredientIds.id=recipes.ingredientId AND ingredientIds.name LIKE '${QUERY}'")
  if [[ ${RESULT} == "" ]]; then
    echo "!!No recipes found with ingredient ${QUERY}!"
    return 1
  fi
  sqlite3 ${DATABASE_FILE} "SELECT DISTINCT recipeIds.name, recipes.amount FROM recipeIds INNER JOIN recipes ON recipeIds.id=recipes.recipeId INNER JOIN ingredientIds ON ingredientIds.id=recipes.ingredientId AND ingredientIds.name LIKE '${QUERY}'"
}

# Outputs all ingredient names associated with a given recipe name.
print_recipes() {
  if [ $# -ne 1 ]; then
    echo "!!No recipe name specified to print!"
    return 1
  fi

  QUERY=$(echo $1 | tr "*" "%")
  
  RESULT=$(sqlite3 ${DATABASE_FILE} "SELECT DISTINCT ingredientIds.name, recipes.amount FROM ingredientIds INNER JOIN recipes ON ingredientIds.id=recipes.ingredientId INNER JOIN recipeIds ON recipeIds.id=recipes.recipeId AND recipeIds.name LIKE '${QUERY}'")
  if [[ ${RESULT} == "" ]]; then
    echo "!!No recipes found with name ${QUERY}!"
    return 1
  fi
  sqlite3 ${DATABASE_FILE} "SELECT DISTINCT ingredientIds.name, recipes.amount FROM ingredientIds INNER JOIN recipes ON ingredientIds.id=recipes.ingredientId INNER JOIN recipeIds ON recipeIds.id=recipes.recipeId AND recipeIds.name LIKE '${QUERY}'"
}



# main
if [ $# -eq 0 ]; then
  echo "No argument specified!"
  echo "The following arguments are accepted: add, dump, search, print"
  exit 1
fi

init_database
check_database

# TODO: search and print may be vulnerable to injections.
# Not that anybody would inject their own personal database,
# but it should probably be looked at sometime.
if [[ $1 == "add" ]]; then
  add_recipe
elif [[ $1 == "dump" ]]; then
  dump_database
elif [[ $1 == "search" ]]; then
  if [[ $# -le 1 ]]; then
    echo "!!No ingredient provided to search!"
    exit 1
  fi
  if [[ $# -eq 2 ]]; then
    search_recipes "$2"
  elif [[ $# -eq 3 ]]; then
    dual_search_recipes "$2" "$3"
  elif [[ $# -ge 4 ]]; then
    echo "No available method to search 3 simultaneous ingredients yet!"
    exit 1
  fi
elif [[ $1 == "print" ]]; then
  if [[ $# -le 1 ]]; then
    echo "!!No recipe provided to print!"
  fi
  print_recipes "$2"
else
  echo "Command $1 not recognized!"
  echo "The following arguments are accepted: add, dump, search, print"
fi

