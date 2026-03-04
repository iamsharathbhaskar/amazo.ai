# Web Tools

## What

You have two web tools available, each suited to different tasks. Knowing when to use which saves time and resources.

## The Tools

### web_fetch (Scrapling) — Your Default

The `web_fetch` tool fetches a web page over HTTP and extracts its text content. It's fast, lightweight, and doesn't launch a browser.

**Use for:**
- Reading documentation, articles, reference material
- Checking a website's content
- Fetching a page during research or absorption
- Any page that works without JavaScript

**Basic usage:**
```
web_fetch(url="https://docs.python.org/3/library/subprocess.html")
```

**With a CSS selector** to extract specific content from noisy pages:
```
web_fetch(url="https://example.com/blog/post", selector="article")
web_fetch(url="https://example.com/docs", selector=".main-content")
```

**Limitations:**
- Does not execute JavaScript. Pages that load content dynamically will return incomplete results.
- Does not handle login flows, CAPTCHAs, or form submissions.
- Truncates output at 15,000 characters to protect your context window.

### Playwright (via bash) — For Interactive Tasks

You have Playwright with Chromium installed. Use it for anything that requires a real browser — JavaScript rendering, login flows, CAPTCHAs, screenshots, form submissions.

**Use for:**
- Pages that require JavaScript to load content
- Login flows and authentication
- CAPTCHAs (use headed mode so your human can solve them)
- Taking screenshots of pages
- Complex multi-step browser interactions

**How to use it:** Write a Python script and run it via bash:
```
bash(cmd="python3 -c \"
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page()
    page.goto('https://example.com')
    print(page.content()[:5000])
    browser.close()
\"")
```

For CAPTCHAs or anything your human needs to see, use `headless=False` and signal your human.

### Scrapling Spiders (via bash) — For Multi-Page Crawling

For crawling multiple pages from a site — following links, traversing sitemaps, bulk scraping — write a Scrapling Spider script:

```python
from scrapling.spiders import Spider, Response

class DocSpider(Spider):
    name = "docs"
    start_urls = ["https://example.com/docs/"]
    concurrent_requests = 3

    async def parse(self, response: Response):
        for link in response.css('a.doc-link'):
            yield {"title": link.text, "url": link.attrib.get("href")}

result = DocSpider().start()
result.items.to_json("results.json")
```

Save the script to my-workshop/ and run it via bash. Review the output before moving it elsewhere.

## When NOT to Fetch

- Respect rate limits. If a site asks you to slow down, slow down.
- Don't scrape sites that explicitly forbid it in their robots.txt or terms of service.
- Don't bulk-download content you don't need. Fetch what's relevant to your task.
- If you're fetching more than 10 pages from one site, write a spider with proper delays between requests.

## Where

Related: my-guides/using-my-workshop.md for testing crawl scripts safely, my-guides/the-amazo-ability.md for using web tools during absorptions.
