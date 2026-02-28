#!/usr/bin/env python3
"""
Web scraper generico para agentes OpenClaw.
Uso: source ~/playwright-env/bin/activate && python3 scripts/web-scraper.py <comando> [args]

Comandos:
  login <url> <email> <senha>     - Login e salva cookies
  fetch <url>                     - Busca pagina (usa cookies salvos)
  list-links <url>                - Lista links da pagina
  screenshot <url> <output.png>   - Screenshot da pagina
"""

import sys, json, os
from playwright.sync_api import sync_playwright

COOKIES_FILE = os.path.expanduser("~/.openclaw/browser-cookies.json")


def save_cookies(context):
    cookies = context.cookies()
    with open(COOKIES_FILE, "w") as f:
        json.dump(cookies, f)
    print(f"Cookies salvos ({len(cookies)} cookies)")


def load_cookies(context):
    if os.path.exists(COOKIES_FILE):
        with open(COOKIES_FILE) as f:
            cookies = json.load(f)
        context.add_cookies(cookies)
        print(f"Cookies carregados ({len(cookies)} cookies)")


def cmd_login(url, email, senha):
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context()
        page = context.new_page()
        page.goto(url, wait_until="networkidle")

        email_sel = page.query_selector(
            'input[type="email"], input[name="email"], input[id*="email"], input[placeholder*="mail"]'
        )
        pass_sel = page.query_selector(
            'input[type="password"], input[name="password"], input[id*="password"]'
        )

        if email_sel and pass_sel:
            email_sel.fill(email)
            pass_sel.fill(senha)

            submit = page.query_selector(
                'button[type="submit"], input[type="submit"], '
                'button:has-text("Entrar"), button:has-text("Login"), button:has-text("Acessar")'
            )
            if submit:
                submit.click()
                page.wait_for_load_state("networkidle")

            print(f"Login resultado - URL: {page.url}")
            print(f"Title: {page.title()}")
            save_cookies(context)
        else:
            print("ERRO: Campos de login nao encontrados")
            print(f"HTML snippet: {page.content()[:500]}")

        browser.close()


def cmd_fetch(url):
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context()
        load_cookies(context)
        page = context.new_page()
        page.goto(url, wait_until="networkidle")

        print(f"URL: {page.url}")
        print(f"Title: {page.title()}")
        print("---CONTENT---")
        text = page.evaluate("() => document.body.innerText")
        print(text[:5000])

        browser.close()


def cmd_list_links(url):
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context()
        load_cookies(context)
        page = context.new_page()
        page.goto(url, wait_until="networkidle")

        links = page.evaluate("""() => {
            return Array.from(document.querySelectorAll('a[href]')).map(a => ({
                text: a.innerText.trim().substring(0, 100),
                href: a.href
            })).filter(l => l.text && l.href.startsWith('http'))
        }""")

        for link in links:
            print(f"{link['text']} -> {link['href']}")

        browser.close()


def cmd_screenshot(url, output):
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context()
        load_cookies(context)
        page = context.new_page()
        page.goto(url, wait_until="networkidle")
        page.screenshot(path=output, full_page=True)
        print(f"Screenshot salvo: {output}")
        browser.close()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == "login" and len(sys.argv) == 5:
        cmd_login(sys.argv[2], sys.argv[3], sys.argv[4])
    elif cmd == "fetch" and len(sys.argv) == 3:
        cmd_fetch(sys.argv[2])
    elif cmd == "list-links" and len(sys.argv) == 3:
        cmd_list_links(sys.argv[2])
    elif cmd == "screenshot" and len(sys.argv) == 4:
        cmd_screenshot(sys.argv[2], sys.argv[3])
    else:
        print(__doc__)
        sys.exit(1)
