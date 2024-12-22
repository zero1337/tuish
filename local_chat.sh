#!/usr/bin/env bash
#
# chat.sh
# A simple text-completion interface that sends queries to an OpenAI-compatible
# endpoint (non-chat) using the "prompt" parameter.

# -- Configuration ------------------------------------------------------------

: "${OPENAI_API_URL:=http://localhost:5001/v1/completions}"
: "${MODEL:=MODEL_NAME}"      # Default model (override with: export MODEL="gpt-3.5-turbo" etc.)
SYSTEM_MSG="You are a helpful assistant."

# -----------------------------------------------------------------------------

echo "      .-::TUIsh::-.         "
echo "Switch to chat pane ctrl+b+:"
echo "Special commands:"
echo "  /flush   - Clear prompt"
echo "  /switch  - Switch to editor"
echo "  /paste   - Paste last response"
echo "  Ctrl-C   - Quit."
echo

# -----------------------------------------------------------------------------
# Instead of storing JSON chat messages, we can just store (and optionally accumulate)
# a prompt. By default, let's keep it empty.
PROMPT=""
LAST_ASSISTANT_CONTENT=""

# Function to either reset or accumulate prompt
flush_prompt() {
  PROMPT=""
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
      flush_prompt
      echo "[Prompt cleared.]"
      continue
      ;;
    /switch)
      tmux select-pane -t 0
      continue
      ;;
    /paste)
      if [ -n "$LAST_ASSISTANT_CONTENT" ]; then
        echo "$LAST_ASSISTANT_CONTENT" | tmux load-buffer -
        tmux select-pane -t 0
        tmux paste-buffer -t 0
      else
        echo "[No assistant response available yet to paste.]"
      fi
      continue
      ;;
    "")
      # If user just hits Enter, do nothing
      continue
      ;;
  esac

  # Option A: Send user input alone (fresh each time)
  # PROMPT="$USER_INPUT"

  # Option B: Accumulate user input into a single prompt
  # If you want to simulate a conversation, uncomment below:
  # PROMPT="${PROMPT}\n${USER_INPUT}"

  # For simplicity, let's assume each user input is a fresh prompt:
  PROMPT="$USER_INPUT"

  # Build the request JSON with prompt-based completion:
  # Adjust any parameters (max_tokens, temperature, etc.) as needed.
  JSON_BODY=$(jq -n \
    --arg model "$MODEL" \
    --arg prompt "$PROMPT" \
    '{
      model: $model,
      prompt: $prompt,
      max_tokens: 512,
      temperature: 0.8
    }'
  )

  # Send request to the (non-chat) endpoint
  RESPONSE=$(curl -s -X POST "$OPENAI_API_URL" \
    -H "Content-Type: application/json" \
    -d "$JSON_BODY")

  # Extract the assistant's text from the JSON response
  ASSISTANT_CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].text // empty')

  if [ -z "$ASSISTANT_CONTENT" ]; then
    echo "Assistant: [No response or error]"
    continue
  fi

  # Save the assistant's response in LAST_ASSISTANT_CONTENT
  LAST_ASSISTANT_CONTENT="$ASSISTANT_CONTENT"

  # Print out the assistant's message
  echo -e "\nAssistant: $ASSISTANT_CONTENT\n"
done
