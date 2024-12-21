#!/usr/bin/env bash
#
# chat.sh
# A simple chat interface that sends queries to an OpenAI-compatible endpoint,
# uses jq for building/parsing JSON, and includes a system message.

# -- Configuration ------------------------------------------------------------

: "${OPENAI_API_URL:=https://api.openai.com/v1/chat/completions}"
: "${MODEL:=gpt-4o-mini}"      # Default model (override with: export MODEL="gpt-3.5-turbo" etc.)
SYSTEM_MSG="You are a helpful assistant."

# -----------------------------------------------------------------------------

echo "      .-::TUIsh::-.         "
echo "Switch to chat pane ctrl+b+:"
echo "Special commands:"
echo "  /flush   - Clear context"
echo "  /switch  - Switch to editor"
echo "  /paste   - Paste last response"
echo "  Ctrl-C   - Quit."
echo

# -----------------------------------------------------------------------------
# We maintain a JSON array of messages in a variable called MESSAGES_JSON.
# Start with a single system message.

MESSAGES_JSON=$(jq -n --arg content "$SYSTEM_MSG" '[{"role":"system","content":$content}]')

# ADDED: Keep track of the last assistant response in this variable
LAST_ASSISTANT_CONTENT=""

# Function to append a new role/content pair to MESSAGES_JSON
add_message() {
  local role="$1"
  local content="$2"
  # Use jq to push a new message object onto the existing array
  MESSAGES_JSON=$(echo "$MESSAGES_JSON" | jq --arg role "$role" --arg content "$content" \
    '. + [{role: $role, content: $content}]')
}

# -----------------------------------------------------------------------------

while true; do
  echo -n "> "
  if ! read -r USER_INPUT; then
    # If we get EOF (Ctrl-D) or a read error, just exit
    echo
    exit 0
  fi

  # Check for special commands
  case "$USER_INPUT" in
    /flush)
      # Reset to just the system message
      MESSAGES_JSON=$(jq -n --arg content "$SYSTEM_MSG" '[{"role":"system","content":$content}]')
      echo "[Context cleared. System message still present.]"
      continue
      ;;
    /switch)
      # Switch focus to the left tmux pane (pane 0)
      tmux select-pane -t 0
      continue
      ;;
    # ADDED: Paste last assistant response into left pane
    /paste)
      if [ -n "$LAST_ASSISTANT_CONTENT" ]; then
        echo "$LAST_ASSISTANT_CONTENT" | tmux load-buffer -
        tmux select-pane -t 0
        tmux paste-buffer -t 0
        # Optionally switch back to the chat pane:
        # tmux select-pane -t 1
      else
        echo "[No assistant response available yet to paste.]"
      fi
      continue
      ;;
    "")
      # If user just hits Enter, skip calling the API
      continue
      ;;
  esac

  # 1) Append user's message to the conversation
  add_message "user" "$USER_INPUT"

  # 2) Build the request JSON with model + the entire messages array
  JSON_BODY=$(jq -n --arg model "$MODEL" --argjson msgs "$MESSAGES_JSON" '
    {
      model: $model,
      messages: $msgs
    }
  ')

  # 3) Send request to the endpoint
  RESPONSE=$(curl -s -X POST "$OPENAI_API_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "$JSON_BODY")

  # 4) Extract the assistant's message content from the JSON response
  ASSISTANT_CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty')

  if [ -z "$ASSISTANT_CONTENT" ]; then
    echo "Assistant: [No response or error]"
    continue
  fi

  # 5) Append the assistant's response to the conversation
  add_message "assistant" "$ASSISTANT_CONTENT"

  # ADDED: Save it in LAST_ASSISTANT_CONTENT
  LAST_ASSISTANT_CONTENT="$ASSISTANT_CONTENT"

  # 6) Print out the assistant's message
  echo -e "\nAssistant: $ASSISTANT_CONTENT\n"
done
