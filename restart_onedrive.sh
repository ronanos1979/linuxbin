osascript -e 'quit app "OneDrive"'
sleep 10
killall "OneDrive" 2>/dev/null
killall "OneDrive File Provider" 2>/dev/null
killall fileproviderd 2>/dev/null
sleep 10
open -a OneDrive
