#!/bin/bash

set -e

# Define functions for printing messages to the user
function print_msg() {
  echo -e "\n\033[1m\033[34m${1}\033[0m\n"
}

function print_error() {
  echo -e "\n\033[1m\033[31mError: ${1}\033[0m\n"
  exit 1
}

# Check that Docker is installed
if ! command -v docker &> /dev/null
then
  print_error "Docker is not installed. Please install Docker and try again."
fi

# Check that Docker is running
if ! docker info &> /dev/null
then
  print_error "Docker is not running. Please start Docker and try again."
fi

# Pull the latest mrsk Docker image
print_msg "Pulling latest mrsk Docker image..."
docker pull ghcr.io/mrsked/mrsk:latest

# Create a bin directory if it does not exist
print_msg "Creating a new directory ~/.mrsk/bin and adding it to the PATH environment variable..."
mkdir -p "$HOME/.mrsk/bin"

# Update the PATH variable to include the mrsk bin directory
if [[ "$PATH" != *"$HOME/.mrsk/bin"* ]]; then
  echo "export PATH=\"\$HOME/.mrsk/bin:\$PATH\"" >> "$HOME/.bashrc"
  echo "export PATH=\"\$HOME/.mrsk/bin:\$PATH\"" >> "$HOME/.zshrc"
  export PATH="$HOME/.mrsk/bin:$PATH"
fi

BIN_DIR="$HOME/.mrsk/bin"

if [[ -z "$BIN_DIR" ]]; then
  print_error "Could not create the bin directory: ~/.mrsk/bin"
fi

# Create a bin file that runs the mrsk Docker image
cat <<EOF > "${BIN_DIR}/mrsk"
#!/bin/sh
MRSK_IMAGE="ghcr.io/mrsked/mrsk:latest"

# Execute the 'docker run' command with the specified flags and arguments
# Set the '--volume' flag to mount the current directory and the Docker socket
docker run -it --rm -v "\$PWD:/workdir" -v "/var/run/docker.sock:/var/run/docker.sock:rw" "\$MRSK_IMAGE" "\$@"
EOF

# Make the bin file executable
chmod +x "${BIN_DIR}/mrsk"

# Test that the mrsk binary was installed correctly
if ! command -v mrsk &> /dev/null
then
  echo -e "\n\e[31mError: mrsk binary was not installed correctly.\e[0m\n"
  exit 1
fi

# Get the version of mrsk
MRSK_VERSION=$(mrsk version | tr -cd '[:alnum:].')

# Thank the user for installing mrsk
print_msg "Thank you for installing mrsk $MRSK_VERSION!"
print_msg "You can now run mrsk by typing 'mrsk init' in your terminal."
