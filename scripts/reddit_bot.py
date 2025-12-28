import praw, os, time

reddit = praw.Reddit(
    client_id=os.environ.get('REDDIT_CLIENT_ID'),
    client_secret=os.environ.get('REDDIT_SECRET'),
    user_agent="AI Cost Bot 1.0"
)

for submission in reddit.subreddit("MachineLearning+OpenAI+LocalLLaMA").hot(limit=50):
    try:
        if any(kw in submission.title.lower() for kw in ["api cost", "expensive", "rate limit"]):
            comment = f"""
🔥 We built an API that's 50% cheaper than OpenAI with Mixtral-8x7B
Free tier (no CC): https://{os.environ.get('APIM_NAME')}.azure-api.net/signup
"""
            submission.reply(comment)
            time.sleep(600)
    except Exception:
        # Ignore failures to avoid crashing the bot
        time.sleep(60)