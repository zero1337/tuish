# TUIsh  

Chat, paste, edit.  

Using OpenAI, export OPENAI_API_KEY -- need to do Ollama 

local_chat.sh and local_tuish.sh connect to a oai endpoint on koboldcpp server

Install tmux, jq, and curl

Don't forget to chmod +x the files

To swtich to the chat pane:
cttl + b + :   

Add the .tmux.conf file to your home dir to use mouse scrolling

On line 32 of tuish.sh, you can remove -Sl after the nano command if you do not want word wrapping and numbered lines
