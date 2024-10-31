#!/bin/sh

# Prompt the user to enter the URL of the .sh file
echo "Please enter the URL of the .sh file:"
read url

# Define the temporary input file name
input_file="/tmp/temp_script.sh"

# Download the .sh file
if ! wget -O "$input_file" "$url"; then
    echo "Failed to download the file."
    exit 1
fi

# Check if the input file was downloaded successfully
if [ ! -s "$input_file" ]; then
    echo "Downloaded file is empty."
    exit 1
fi

# Define the output file name in the temporary directory
output_file="/tmp/ezp.b64"

# Convert to Base64 and add line breaks every 100 characters using awk
if ! base64 "$input_file" | awk '{ for (i=1; i<=length; i+=100) print substr($0, i, 100) }' > "$output_file"; then
    echo "Failed to convert to Base64."
    exit 1
fi

# Clean up the temporary file
rm "$input_file"

echo "Base64 file saved as ezp.b64 in /tmp."
