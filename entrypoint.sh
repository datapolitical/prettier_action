#!/bin/bash
# e is for exiting the script automatically if a command fails, u is for exiting if a variable is not set
# x would be for showing the commands before they are executed
set -eu
shopt -s globstar

# FUNCTIONS
# Function for setting up git env in the docker container (copied from https://github.com/stefanzweifel/git-auto-commit-action/blob/master/entrypoint.sh)
_git_setup ( ) {
    cat <<- EOF > $HOME/.netrc
      machine github.com
      login $GITHUB_ACTOR
      password $INPUT_GITHUB_TOKEN
      machine api.github.com
      login $GITHUB_ACTOR
      password $INPUT_GITHUB_TOKEN
EOF
    chmod 600 $HOME/.netrc

    git config --global user.email "actions@github.com"
    git config --global user.name "GitHub Action"
}

# Checks if any files are changed
_git_changed() {
    [[ -n "$(git status -s)" ]]
}

_git_changes() {
    git diff
}

(
# PROGRAM
# Changing to the directory
cd "$GITHUB_ACTION_PATH"

echo "Installing prettier..."

case $INPUT_WORKING_DIRECTORY in
    false)
        ;;
    *)
        cd $INPUT_WORKING_DIRECTORY
        ;;
esac

case $INPUT_PRETTIER_VERSION in
    false)
        npm install --silent prettier
        ;;
    *)
        npm install --silent prettier@$INPUT_PRETTIER_VERSION
        ;;
esac

# Install plugins
if [ -n "$INPUT_PRETTIER_PLUGINS" ]; then
    for plugin in $INPUT_PRETTIER_PLUGINS; do
        echo "Checking plugin: $plugin"
        # check regex against @prettier/xyz
        if ! echo "$plugin" | grep -Eq '(@prettier\/)+(plugin-[a-z\-]+)'; then
            echo "$plugin does not seem to be a valid @prettier/plugin-x plugin. Exiting."
            exit 1
        fi
    done
    npm install --silent --global $INPUT_PRETTIER_PLUGINS
fi
)

PRETTIER_RESULT=0
echo "Prettifying files..."
echo "Files:"
prettier $INPUT_PRETTIER_OPTIONS \
  || { PRETTIER_RESULT=$?; echo "Problem running prettier with $INPUT_PRETTIER_OPTIONS"; exit 1; }

# Ignore node modules and other action created files
if [ -d 'node_modules' ]; then
  rm -r node_modules/
else
  echo "No node_modules/ folder."
fi

# To keep runtime good, just continue if something was changed
if _git_changed; then
  # case when --write is used with dry-run so if something is unpretty there will always have _git_changed
  if $INPUT_DRY; then
    echo "Unpretty Files Changes:"
    _git_changes
    echo "Finishing dry-run. Some files have been changed. Commit the changes if you want to keep them."
    exit 0
  else
    echo "This should only be run in dry mode"
  fi
else
  # case when --check is used so there will never have something to commit but there are unpretty files
  if [ "$PRETTIER_RESULT" -eq 1 ]; then
    echo "Prettier found unpretty files!"
    exit 1
  else
    echo "Finishing dry-run."
  fi
  echo "No unpretty files! Exiting."
fi
