module globals;

static immutable auto HOST="irc.twitch.tv",
                      PORT=6667;
static shared auto    OWNER="",
                      NICK="",
                      PASS="",
                      CHAN="",
                      STARTUP="",
                      SHUTDOWN="";
static bool           SHOW_OPTIONS=true,
                      SHOW_SALUTATIONS=true;