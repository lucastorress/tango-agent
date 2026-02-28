#!/usr/bin/env python3
"""
Web scraper generico para agentes OpenClaw.
Uso: source ~/playwright-env/bin/activate && python3 ~/tango-agent/scripts/web-scraper.py <comando> [args]

Comandos:
  login <url> <email> <senha>     - Login e salva cookies (espera redirecionamento)
  fetch <url>                     - Busca pagina e retorna texto (usa cookies)
  list-links <url>                - Lista links da pagina (usa cookies)
  screenshot <url> <output.png>   - Screenshot full-page (usa cookies)
  crawl <url> [depth]             - Crawl recursivo listando todas as paginas (default depth=1)
"""

import sys, json, os, time
from playwright.sync_api import sync_playwright

COOKIES_FILE = os.path.expanduser("~/.openclaw/browser-cookies.json")
TIMEOUT = 30000


def save_cookies(context):
    cookies = context.cookies()
    os.makedirs(os.path.dirname(COOKIES_FILE), exist_ok=True)
    with open(COOKIES_FILE, "w") as f:
        json.dump(cookies, f)
    print(f"Cookies salvos ({len(cookies)} cookies)")


def load_cookies(context):
    if os.path.exists(COOKIES_FILE):
        with open(COOKIES_FILE) as f:
            cookies = json.load(f)
        context.add_cookies(cookies)
        print(f"Cookies carregados ({len(cookies)} cookies)")
        return True
    return False


def make_context(p):
    browser = p.chromium.launch(headless=True)
    context = browser.new_context(
        user_agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
        viewport={"width": 1280, "height": 720},
    )
    load_cookies(context)
    return browser, context


def cmd_login(url, email, senha):
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            user_agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
            viewport={"width": 1280, "height": 720},
        )
        page = context.new_page()
        page.goto(url, wait_until="networkidle", timeout=TIMEOUT)

        # Tentar varios seletores de email
        email_sel = page.query_selector(
            'input[type="email"], input[name="email"], input[id*="email"], '
            'input[placeholder*="mail"], input[placeholder*="Email"], '
            'input[name="username"], input[id*="user"]'
        )
        pass_sel = page.query_selector(
            'input[type="password"], input[name="password"], input[id*="password"], '
            'input[id*="senha"], input[name="senha"]'
        )

        if email_sel and pass_sel:
            email_sel.fill(email)
            time.sleep(0.5)
            pass_sel.fill(senha)
            time.sleep(0.5)

            submit = page.query_selector(
                'button[type="submit"], input[type="submit"], '
                'button:has-text("Entrar"), button:has-text("Login"), '
                'button:has-text("Acessar"), button:has-text("Sign in"), '
                'button:has-text("Continuar")'
            )
            if submit:
                submit.click()
                # Esperar navegacao pos-login (pode redirecionar)
                try:
                    page.wait_for_load_state("networkidle", timeout=15000)
                except:
                    pass
                # Esperar mais um pouco caso tenha JS redirect
                time.sleep(2)
                try:
                    page.wait_for_load_state("networkidle", timeout=10000)
                except:
                    pass

            print(f"URL final: {page.url}")
            print(f"Title: {page.title()}")
            save_cookies(context)

            # Mostrar preview do conteudo pos-login
            try:
                text = page.evaluate("() => document.body.innerText")
                print("---PREVIEW---")
                print(text[:2000])
            except:
                pass
        else:
            print("ERRO: Campos de login nao encontrados")
            # Mostrar o HTML para debug
            html = page.content()
            print(f"URL: {page.url}")
            print(f"Title: {page.title()}")
            # Listar inputs encontrados
            inputs = page.evaluate("""() => {
                return Array.from(document.querySelectorAll('input')).map(i => ({
                    type: i.type, name: i.name, id: i.id, placeholder: i.placeholder
                }))
            }""")
            print("Inputs encontrados:")
            for inp in inputs:
                print(f"  type={inp['type']} name={inp['name']} id={inp['id']} placeholder={inp['placeholder']}")

        browser.close()


def cmd_fetch(url):
    with sync_playwright() as p:
        browser, context = make_context(p)
        page = context.new_page()
        page.goto(url, wait_until="networkidle", timeout=TIMEOUT)

        print(f"URL: {page.url}")
        print(f"Title: {page.title()}")
        print("---CONTENT---")
        text = page.evaluate("() => document.body.innerText")
        print(text[:10000])

        browser.close()


def cmd_list_links(url):
    with sync_playwright() as p:
        browser, context = make_context(p)
        page = context.new_page()
        page.goto(url, wait_until="networkidle", timeout=TIMEOUT)

        print(f"URL: {page.url}")
        print(f"Title: {page.title()}")
        print("---LINKS---")

        links = page.evaluate("""() => {
            const seen = new Set();
            return Array.from(document.querySelectorAll('a[href]'))
                .map(a => ({ text: a.innerText.trim().substring(0, 120), href: a.href }))
                .filter(l => {
                    if (!l.text || !l.href.startsWith('http') || seen.has(l.href)) return false;
                    seen.add(l.href);
                    return true;
                })
        }""")

        for link in links:
            print(f"{link['text']} -> {link['href']}")

        print(f"\nTotal: {len(links)} links unicos")
        browser.close()


def cmd_screenshot(url, output):
    with sync_playwright() as p:
        browser, context = make_context(p)
        page = context.new_page()
        page.goto(url, wait_until="networkidle", timeout=TIMEOUT)
        os.makedirs(os.path.dirname(output) if os.path.dirname(output) else ".", exist_ok=True)
        page.screenshot(path=output, full_page=True)
        print(f"Screenshot salvo: {output}")
        print(f"URL: {page.url}")
        browser.close()


def cmd_crawl(url, max_depth=1):
    visited = set()
    to_visit = [(url, 0)]
    base_domain = url.split("//")[1].split("/")[0] if "//" in url else url

    with sync_playwright() as p:
        browser, context = make_context(p)

        while to_visit:
            current_url, depth = to_visit.pop(0)
            if current_url in visited or depth > max_depth:
                continue
            visited.add(current_url)

            page = context.new_page()
            try:
                page.goto(current_url, wait_until="networkidle", timeout=TIMEOUT)
                title = page.title()
                text_preview = page.evaluate("() => document.body.innerText")[:200].replace("\n", " ")
                print(f"[depth={depth}] {title} -> {page.url}")
                print(f"  Preview: {text_preview}")

                if depth < max_depth:
                    links = page.evaluate("""() => {
                        return Array.from(document.querySelectorAll('a[href]'))
                            .map(a => a.href)
                            .filter(h => h.startsWith('http'))
                    }""")
                    for link in links:
                        link_domain = link.split("//")[1].split("/")[0] if "//" in link else ""
                        if link_domain == base_domain and link not in visited:
                            to_visit.append((link, depth + 1))
            except Exception as e:
                print(f"[depth={depth}] ERRO: {current_url} -> {e}")
            finally:
                page.close()

        print(f"\nTotal paginas visitadas: {len(visited)}")
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
    elif cmd == "crawl":
        depth = int(sys.argv[3]) if len(sys.argv) > 3 else 1
        cmd_crawl(sys.argv[2], depth)
    else:
        print(__doc__)
        sys.exit(1)
