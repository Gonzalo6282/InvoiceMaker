"""Builds the website's Privacy, Terms and Support pages.

Privacy and Terms come from the app's own text (InvoiceMaker/Resources/Legal),
so the website and the app always say the same thing. Run from the repo root:
    python3 website/build.py
"""
import html
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent
LEGAL = ROOT.parent / "InvoiceMaker" / "Resources" / "Legal"
EMAIL = "slice.of.life.ltd@gmail.com"


def inline(text):
    text = html.escape(text)
    text = re.sub(r"(https?://[^\s<,)]*[^\s<,).])", r'<a href="\1">\1</a>', text)
    text = re.sub(r"([\w.+-]+@[\w-]+\.[\w.]*\w)", r'<a href="mailto:\1">\1</a>', text)
    return text


def legal_body(path):
    out, in_list, title, updated = [], False, "", ""
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("- "):
            if not in_list:
                out.append("<ul>")
                in_list = True
            out.append(f"<li>{inline(line[2:])}</li>")
            continue
        if in_list:
            out.append("</ul>")
            in_list = False
        if line.startswith("### "):
            out.append(f"<h3>{inline(line[4:])}</h3>")
        elif line.startswith("## "):
            out.append(f"<h2>{inline(line[3:])}</h2>")
        elif line.startswith("# "):
            title = line[2:]
        elif line.startswith(("Last updated", "Dernière mise à jour", "Zuletzt aktualisiert", "Última actualización")) and not updated:
            updated = line
        else:
            out.append(f"<p>{inline(line)}</p>")
    if in_list:
        out.append("</ul>")
    return title, updated, "\n".join(out)


LOGO = "data:image/png;base64,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"
SITE = "https://slice-of-life.uk"
APP = "https://apps.apple.com/us/app/invoice-maker-estimate-duly/id6824285908"

# Same look and links as the /duly/ landing page (nav pill, footer columns), so
# every Duly page on WordPress matches it. The theme's own header and footer are
# hidden on these pages, like on /duly/.
WP_STYLE = """<style>
body:has(.duly-page) .site-header,body:has(.duly-page) .site-footer,body:has(.duly-page) header.wp-block-template-part,body:has(.duly-page) footer.wp-block-template-part,body:has(.duly-page) .entry-header,body:has(.duly-page) .wp-block-post-title,body:has(.duly-page) .page-header{display:none!important}
body:has(.duly-page),body:has(.duly-page) .wp-site-blocks,body:has(.duly-page) main,body:has(.duly-page) .entry-content{margin-top:0!important;padding-top:0!important;margin-bottom:0!important;padding-bottom:0!important;max-width:none!important;background:#fff!important}
body:has(.duly-page) .wp-site-blocks>*,body:has(.duly-page) .entry-content>*{margin-block:0!important;max-width:none!important}
body:has(.duly-page){overflow-x:clip}
.duly-page{width:100%!important;max-width:none!important;margin:0!important;font-family:Inter,ui-sans-serif,system-ui,-apple-system,"Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif;color:#061b31;line-height:1.6;-webkit-font-smoothing:antialiased}
.duly-page *{box-sizing:border-box}
.duly-page a{color:#533afd}
.duly-page .dp-shell{position:sticky;top:12px;z-index:100;padding:0 14px;margin-bottom:-70px}
.admin-bar .duly-page .dp-shell{top:46px}
@media(min-width:783px){.admin-bar .duly-page .dp-shell{top:44px}}
.duly-page .dp-nav{max-width:760px;margin:12px auto 0;height:58px;display:flex;align-items:center;gap:16px;padding:8px 8px 8px 18px;background:rgba(255,255,255,.9);border:1px solid rgba(6,27,49,.08);border-radius:999px;box-shadow:0 8px 28px rgba(6,27,49,.14);-webkit-backdrop-filter:blur(16px) saturate(1.5);backdrop-filter:blur(16px) saturate(1.5)}
.duly-page .dp-brand{display:flex;align-items:center;gap:10px;font-size:20.8px;font-weight:800;color:#061b31;text-decoration:none;letter-spacing:-.02em}
.duly-page .dp-brand img{width:34px;height:34px;border-radius:9px;display:block}
.duly-page .dp-links{display:flex;flex:1;justify-content:center}
.duly-page .dp-links a{font-size:14.5px;font-weight:500;color:#50617a;padding:9px 15px;border-radius:999px;text-decoration:none}
.duly-page .dp-links a:hover{color:#061b31;background:rgba(6,27,49,.05)}
.duly-page .dp-cta{background:#533afd;color:#fff!important;border-radius:999px;padding:11px 20px;font-size:15px;font-weight:500;text-decoration:none;white-space:nowrap;margin-left:auto}
.duly-page .dp-cta:hover{background:#4330e0}
@media(max-width:820px){.duly-page .dp-links{display:none}}
.duly-page .dp-hero{background:radial-gradient(120% 140% at 0% 0%,#3d2bd6 0%,#1b2a8a 30%,#0a2540 65%);color:#fff;padding:150px 20px 72px}
.duly-page .dp-hero-in{max-width:720px;margin:0 auto}
.duly-page .dp-doc>h2:first-child{margin-top:0}
.duly-page .dp-eyebrow{color:#9fe870;font-size:12.5px;font-weight:600;letter-spacing:1.5px;text-transform:uppercase;margin:0 0 14px}
.duly-page .dp-hero h1{font-size:clamp(40px,7vw,64px);font-weight:900;line-height:.95;letter-spacing:-.045em;text-transform:uppercase;margin:0;color:#fff}
.duly-page .dp-hero p.dp-updated{color:rgba(255,255,255,.72);font-size:15px;margin:18px 0 0}
.duly-page .dp-hero p.dp-updated a{color:#9fe870}
.duly-page .dp-doc{max-width:760px;margin:0 auto;padding:56px 20px 80px}
.duly-page .dp-doc h2{font-size:1.4rem;line-height:1.25;letter-spacing:-.01em;margin:1.9em 0 .45em;color:#061b31}
.duly-page .dp-doc h3{font-size:1.06rem;margin:1.5em 0 .3em;color:#061b31}
.duly-page .dp-doc p,.duly-page .dp-doc li{font-size:16px;color:#33435a}
.duly-page .dp-doc ul{padding-left:1.2em}
.duly-page .dp-doc .toc{background:#f8fafd;border:1px solid rgba(6,27,49,.08);border-radius:16px;padding:18px 22px;margin:0 0 8px}
.duly-page .dp-doc .toc ul{margin:0;padding-left:1.1em}
.duly-page .dp-foot{background:#f8fafd;padding:72px 20px 32px;border-top:1px solid rgba(6,27,49,.06)}
.duly-page .dp-foot-in{max-width:1120px;margin:0 auto;display:grid;grid-template-columns:1.6fr 1fr 1fr;gap:48px}
.duly-page .dp-foot p{color:#50617a;font-size:15px;margin:14px 0 0;max-width:340px}
.duly-page .dp-foot h4{font-size:12.5px;font-weight:600;color:#64748d;text-transform:uppercase;letter-spacing:1.5px;margin:0 0 14px}
.duly-page .dp-foot-col a{display:block;font-size:15px;line-height:22.5px;color:#061b31;text-decoration:none;margin:0 0 10px}
.duly-page .dp-foot-col a:hover{color:#533afd}
.duly-page .dp-foot-end{max-width:1120px;margin:48px auto 0;padding-top:24px;border-top:1px solid rgba(6,27,49,.08)}
.duly-page .dp-foot-end p{max-width:none;font-size:13.5px;margin:0 0 6px}
.duly-page .dp-foot-end .tiny{font-size:12px;color:#7a8aa3}
@media(max-width:720px){.duly-page .dp-foot-in{grid-template-columns:1fr 1fr}.duly-page .dp-foot-brand{grid-column:1/-1}}
</style>"""

WP_NAV = f"""<div class="dp-shell"><div class="dp-nav">
  <a class="dp-brand" href="{SITE}/duly/" aria-label="Duly home"><img src="{LOGO}" alt="">Duly</a>
  <nav class="dp-links" aria-label="Main">
    <a href="{SITE}/duly/#features">Features</a>
    <a href="{SITE}/duly/#how">How it works</a>
    <a href="{SITE}/duly/#templates">Templates</a>
    <a href="{SITE}/duly/#get-paid">Get paid</a>
    <a href="{SITE}/duly/#faq">FAQ</a>
  </nav>
  <a class="dp-cta" href="{APP}" target="_blank" rel="noopener noreferrer">Get the app</a>
</div></div>"""

WP_FOOT = f"""<footer class="dp-foot">
  <div class="dp-foot-in">
    <div class="dp-foot-brand">
      <a class="dp-brand" href="{SITE}/duly/"><img src="{LOGO}" alt="">Duly</a>
      <p>Invoice maker and estimate app for tradespeople, freelancers and small businesses. For iPhone and iPad.</p>
    </div>
    <div class="dp-foot-col">
      <h4>Product</h4>
      <a href="{SITE}/duly/#features">Features</a>
      <a href="{SITE}/duly/#how">How it works</a>
      <a href="{SITE}/duly/#templates">Templates</a>
      <a href="{SITE}/duly/#plans">What’s included</a>
      <a href="{SITE}/duly/#faq">FAQ</a>
    </div>
    <div class="dp-foot-col">
      <h4>Company</h4>
      <a href="{SITE}/duly-privacy/">Privacy Policy</a>
      <a href="{SITE}/duly-terms/">Terms of Use</a>
      <a href="{SITE}/duly-support/">Support</a>
      <a href="mailto:{EMAIL}">Contact</a>
      <a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/">Apple Standard EULA</a>
    </div>
  </div>
  <div class="dp-foot-end">
    <p>© 2026 Slice of Life Ltd. Duly is published by Slice of Life Ltd.</p>
    <p class="tiny">Apple, iPhone, iPad, iCloud, AirDrop and App Store are trademarks of Apple Inc.</p>
  </div>
</footer>"""

def wordpress(name, content, lang="en", eyebrow="Duly"):
    """One Custom HTML block per WordPress page, with the /duly/ nav and footer
    and the styles inside, so it is the only thing to paste."""
    content = content.replace('href="../', f'href="{SITE}/')
    m = re.match(r"\s*<h1>(.*?)</h1>\s*(<p class=\"updated\">(.*?)</p>)?", content, re.S)
    title, updated = m.group(1), m.group(3)
    body = content[m.end():]
    upd = f'\n    <p class="dp-updated">{updated}</p>' if updated else ""
    snippet = f"""{WP_STYLE}
<div class="duly-page" lang="{lang}">
{WP_NAV}
<header class="dp-hero"><div class="dp-hero-in">
    <p class="dp-eyebrow">{eyebrow}</p>
    <h1>{title}</h1>{upd}
</div></header>
<div class="dp-doc">
{body.strip()}
</div>
{WP_FOOT}
</div>
"""
    out = ROOT / "wordpress" / f"{name}.html"
    out.parent.mkdir(exist_ok=True)
    out.write_text(snippet, encoding="utf-8")


def page(title, description, body, lang="en"):
    return f"""<!doctype html>
<html lang="{lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)} · Duly</title>
<meta name="description" content="{html.escape(description)}">
<link rel="icon" href="../assets/icon-64.png">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Inter+Tight:wght@600;700;800;900&display=swap" rel="stylesheet">
<link rel="stylesheet" href="../assets/site.css">
</head>
<body>
<a class="skip" href="#main">Skip to content</a>
<header class="site-header">
  <div class="wrap">
    <a class="brand" href="../"><img src="../assets/icon-64.png" alt="">Duly</a>
    <nav class="site-nav" aria-label="Main">
      <a href="../#features">Features</a>
      <a href="../#how">How it works</a>
      <a href="../#templates">Templates</a>
      <a href="../#get-paid">Get paid</a>
      <a href="../#faq">FAQ</a>
    </nav>
    <a class="btn btn-primary btn-sm" href="https://apps.apple.com/app/id6824285908">Get the app</a>
  </div>
</header>
<main id="main" class="doc">
{body}
</main>
<footer class="site-footer">
  <div class="wrap">
    <div>
      <a class="brand" href="../"><img src="../assets/icon-64.png" alt="">Duly</a>
      <p>Made by Slice of Life Ltd, a company registered in the United Kingdom.</p>
    </div>
    <div>
      <h4>Help</h4>
      <ul><li><a href="../duly-help/">Help guide</a></li><li><a href="../duly-support/">Support</a></li><li><a href="mailto:{EMAIL}">{EMAIL}</a></li></ul>
    </div>
    <div>
      <h4>Legal</h4>
      <ul><li><a href="../duly-privacy/">Privacy Policy</a></li><li><a href="../duly-terms/">Terms of Use</a></li></ul>
    </div>
  </div>
</footer>
</body>
</html>
"""


SUPPORT = f"""<h1>Support</h1>
<p class="updated">We reply to every message within 24 hours.</p>
<p>Email <a href="mailto:{EMAIL}?subject=Duly%20support">{EMAIL}</a>, or in the app go to Settings &gt; Report a problem. That opens an email with your app version and device already filled in, which helps us fix things faster.</p>
<p>Step-by-step answers for everything in the app are in the <a href="../duly-help/">Help guide</a>.</p>

<h2>Common questions</h2>
<h3>Do I need an account?</h3>
<p>No. Duly works as soon as you open it. Sign in with Apple is optional and only links your subscription across your devices.</p>
<h3>What can I do without paying?</h3>
<p>Create, edit and preview as many invoices, estimates and receipts as you like, save clients and items, back up to iCloud and export your data. Sending, printing and saving PDFs need Duly Premium.</p>
<h3>Where are my invoices stored?</h3>
<p>On your device and in your own iCloud. We never upload them to our servers and we can't see them. Keep iCloud turned on so a new iPhone or iPad gets everything back.</p>
<h3>My invoices didn't come back on a new phone</h3>
<p>Check that you're signed in to the same Apple ID and that iCloud has free space. In Duly, Settings &gt; iCloud backup shows when the last backup and restore happened, and the reason if one failed.</p>
<h3>How do my customers pay me?</h3>
<p>Add your bank details and payment links (PayPal, Venmo, Zelle, Cash App or any payment link) in Settings &gt; Payment details. They appear on every invoice with a QR code. Payments go straight to you.</p>
<h3>How do I restore my subscription?</h3>
<p>Settings &gt; Account &gt; Restore purchases, signed in to the same Apple ID you subscribed with.</p>
<h3>How do I cancel?</h3>
<p>Payments are handled by Apple. Open Settings on your iPhone, tap your name, then Subscriptions. Deleting the app does not cancel the subscription. For a refund, go to <a href="https://reportaproblem.apple.com">reportaproblem.apple.com</a>.</p>
<h3>How do I export everything?</h3>
<p>Settings &gt; Export everything makes a ZIP with every PDF and a CSV of your documents, clients and items.</p>
<h3>How do I delete my account?</h3>
<p>Settings &gt; Account &gt; Delete account. Your invoices stay on your device and in your iCloud; delete the app to remove them.</p>
"""

HELP = f"""<h1>Help guide</h1>
<p class="updated">Everything Duly does, and how to fix the common problems. Still stuck? Email <a href="mailto:{EMAIL}?subject=Duly%20help">{EMAIL}</a>; we reply within 24 hours.</p>
<nav class="toc" aria-label="On this page">
<ul>
<li><a href="#start">Getting started</a></li>
<li><a href="#documents">Invoices, estimates and receipts</a></li>
<li><a href="#sending">Sending, printing and PDFs</a></li>
<li><a href="#paid">Getting paid</a></li>
<li><a href="#taxes">Taxes, discounts and currencies</a></li>
<li><a href="#look">Logo, templates and signature</a></li>
<li><a href="#icloud">iCloud backup and a new phone</a></li>
<li><a href="#premium">Duly Premium</a></li>
<li><a href="#account">Account and Sign in with Apple</a></li>
<li><a href="#problems">Fixing problems</a></li>
</ul>
</nav>

<h2 id="start">Getting started</h2>
<h3>Do I need an account?</h3>
<p>No. Duly works as soon as you open it. Sign in with Apple is optional: it only links your subscription to your Apple ID so it follows you to a new iPhone or iPad.</p>
<h3>How do I make my first invoice?</h3>
<p>The first time you open Duly it asks what you do and your business name, then shows a sample invoice you can edit. After that, tap <strong>+</strong> on the Invoices screen. Add a client, add items with a price, and the total is worked out for you. Everything saves as you type.</p>
<h3>Where do I put my business details?</h3>
<p>Settings &gt; Business profile: name, address, email, phone, country, tax number and default currency. They print at the top of every document.</p>
<h3>Does Duly work on iPad?</h3>
<p>Yes. On iPad you see your list and the document side by side, and in landscape the PDF updates live next to the editor. Press ⌘N for a new invoice and ⌘S to save.</p>

<h2 id="documents">Invoices, estimates and receipts</h2>
<h3>How do I turn an estimate into an invoice?</h3>
<p>Open the estimate (called a quote in the UK) and tap <strong>Turn into invoice</strong>. Duly copies the client and items to a new invoice and marks the estimate as invoiced.</p>
<h3>Can my client sign an estimate?</h3>
<p>Yes. Open it, tap the <strong>…</strong> menu, then <strong>Client signs on this device</strong>, and hand over your phone. Their signature, name and the date go on the PDF and the estimate is marked accepted.</p>
<h3>How do I mark an invoice as paid?</h3>
<p>Open it and choose <strong>Mark as paid</strong> from the <strong>…</strong> menu, or touch and hold it in the list. Then tap <strong>Make receipt</strong> to send your client a receipt as proof.</p>
<h3>When does an invoice show as overdue?</h3>
<p>The day after its due date, if it has been sent and isn't marked paid. You set the usual number of days in Settings &gt; Numbers and defaults.</p>
<h3>Can I change the invoice numbers?</h3>
<p>Yes. Settings &gt; Numbers and defaults sets the prefixes (for example INV-) and the next number. You can also edit the number on any document.</p>
<h3>How do I copy an old invoice?</h3>
<p>Open it, tap <strong>…</strong> and choose <strong>Duplicate</strong>. You get a new draft with a new number and today's date.</p>
<h3>Can I save items I charge for often?</h3>
<p>Yes. Add them in the Items tab, or switch on <strong>Save to my items</strong> when you add a line. Then use <strong>Add from saved items</strong> on any invoice.</p>

<h2 id="sending">Sending, printing and PDFs</h2>
<h3>How do I send an invoice?</h3>
<p>Tap <strong>Send</strong>. Duly makes the PDF and opens the share sheet: email, Messages, WhatsApp, AirDrop or any other app. The invoice is marked as sent.</p>
<h3>Can I print it or save the PDF?</h3>
<p>Yes. Tap <strong>…</strong> on the document, then <strong>Print</strong> or <strong>Save PDF to Files</strong>.</p>
<h3>Why does my PDF say "Preview"?</h3>
<p>Previews are free and carry a light "Preview" mark. Sent, printed and saved PDFs with Duly Premium have no mark.</p>
<h3>Can I send without signal?</h3>
<p>Yes. Mail and WhatsApp keep the message and send it as soon as you're back online.</p>
<h3>I changed an invoice after sending it</h3>
<p>Changes save automatically. Tap <strong>Send again</strong> so your client has the latest version.</p>

<h2 id="paid">Getting paid</h2>
<h3>How do my clients pay me?</h3>
<p>Add your bank details and payment links in Settings &gt; Payment details. They print on every invoice as buttons and a QR code, and your client pays you directly. Duly never touches the money.</p>
<h3>Which payment links can I add?</h3>
<p>PayPal.me, Venmo, Cash App, Zelle, and any Stripe or Square payment link, plus bank transfer details (sort code, routing number, IBAN or SWIFT).</p>
<h3>Why does my client have to type the amount?</h3>
<p>A general payment link (like PayPal.me) can't know each invoice's total, so your client types it in. The total is right above the buttons.</p>

<h2 id="taxes">Taxes, discounts and currencies</h2>
<h3>How do I set up VAT, GST or sales tax?</h3>
<p>Duly starts with the usual rates for your country (VAT in the UK, GST in Australia, GST/PST/QST/HST in Canada, sales tax in the US). Change them or add your own in Settings &gt; Taxes. Changing a rate never changes invoices you've already sent.</p>
<h3>Can prices include tax?</h3>
<p>Yes. In an invoice's <strong>Tax and discount</strong> section, choose <strong>Tax included</strong> or <strong>Tax added</strong>, and whether tax applies per item or on the total.</p>
<h3>Can I add a discount, shipping or a fee?</h3>
<p>Yes, all three are in <strong>Tax and discount</strong>. A discount can be a percentage or an amount, on the whole invoice or on a single line.</p>
<h3>Can one client pay in another currency?</h3>
<p>Yes. Set the currency in the client's details and their new invoices use it. Settings &gt; Currency display shows amounts with a symbol, a code or no currency.</p>

<h2 id="look">Logo, templates and signature</h2>
<h3>How do I add my logo?</h3>
<p>Settings &gt; Business profile &gt; Add your logo, from Photos (JPEG, PNG or HEIC). It's shown whole and never cropped.</p>
<h3>Which templates are there?</h3>
<p>Seven: Clean, Bold and Ledger are free; Studio, Trades, Classic and Split come with Premium. Pick a default and a brand colour in Settings &gt; Invoice look, or change them on one invoice in Preview.</p>
<h3>Can I sign my invoices?</h3>
<p>Yes. Draw your signature once in Settings &gt; My signature and it goes on every invoice.</p>
<h3>How do I remove "Made with Duly"?</h3>
<p>Settings &gt; Invoice look &gt; Footer, and turn off Show "Made with Duly" on PDFs. It's the small line at the bottom of your PDFs. Turning it off is free and doesn't need Premium; it applies to every PDF you make from then on.</p>

<h2 id="icloud">iCloud backup and a new phone</h2>
<h3>Where are my invoices stored?</h3>
<p>On your device and in your own private iCloud. We never upload them to our servers and we can't see them.</p>
<h3>How do I get my invoices on a new iPhone or iPad?</h3>
<p>Sign in to the same Apple ID with iCloud turned on and install Duly. Open it and wait a moment: it looks for your invoices in iCloud before showing the welcome screens.</p>
<h3>My invoices didn't come back</h3>
<p>Check that you're signed in to the same Apple ID, that iCloud is on for Duly (iPhone Settings &gt; your name &gt; iCloud), and that your iCloud storage isn't full. In Duly, Settings &gt; iCloud backup shows the last backup and restore, and the reason if one failed.</p>
<h3>How do I export everything?</h3>
<p>Settings &gt; Export everything makes a ZIP with every PDF and a CSV of your documents, clients and items. It's free.</p>

<h2 id="premium">Duly Premium</h2>
<h3>What's free and what needs Premium?</h3>
<p>Free: create, edit and preview as many invoices, estimates and receipts as you like, save clients and items, back up to iCloud and export your data. Premium: send, print and save PDFs, the four extra templates, and PDFs without the preview mark.</p>
<h3>How do I restore my subscription?</h3>
<p>Settings &gt; Account &gt; Restore purchases, signed in to the App Store with the Apple ID you subscribed with.</p>
<h3>How do I cancel?</h3>
<p>Subscriptions are handled by Apple. On your iPhone open Settings, tap your name, then Subscriptions, then Duly. Deleting the app does not cancel the subscription. If it ends, you keep every document.</p>
<h3>How do I get a refund?</h3>
<p>Apple handles refunds: go to <a href="https://reportaproblem.apple.com">reportaproblem.apple.com</a> and choose the purchase.</p>

<h2 id="account">Account and Sign in with Apple</h2>
<h3>Why would I sign in?</h3>
<p>Only so your subscription follows your Apple ID to a new device. Your invoices are in iCloud either way.</p>
<h3>How do I delete my account?</h3>
<p>Settings &gt; Account &gt; Delete account, then confirm with Apple. Your invoices stay on your device and in your iCloud; delete the app to remove them. Deleting your account doesn't cancel a subscription.</p>

<h2 id="problems">Fixing problems</h2>
<h3>"Sign in with Apple" shows an error (1000)</h3>
<p>Apple's link to Duly needs resetting. On your iPhone open Settings, tap your name, then Sign-In &amp; Security &gt; Sign in with Apple &gt; Duly, and tap <strong>Stop Using Apple ID</strong>. Then go back to Duly and try again.</p>
<h3>I paid but Send still asks me to subscribe</h3>
<p>Go to Settings &gt; Account &gt; Restore purchases. Make sure the App Store is signed in to the Apple ID you paid with.</p>
<h3>The share sheet doesn't show my email app</h3>
<p>Scroll the row of apps to the end and tap <strong>More</strong> to add it, or use <strong>Save PDF to Files</strong> and attach the file yourself.</p>
<h3>Something else isn't working</h3>
<p>Settings &gt; Report a problem sends us your message with the app version and device model. We reply within 24 hours.</p>
"""


def main():
    for name, src, desc, lang in [
        ("duly-privacy", "privacy.txt", "How Duly handles your information.", "en"),
        ("duly-terms", "terms.txt", "The terms for using Duly: Invoice Maker & Estimate.", "en"),
        ("duly-privacy-fr", "privacy.fr.txt", "Comment Duly traite vos informations.", "fr"),
        ("duly-terms-fr", "terms.fr.txt", "Les conditions d'utilisation de Duly: Invoice Maker & Estimate.", "fr"),
        ("duly-privacy-de", "privacy.de.txt", "Wie Duly mit Ihren Informationen umgeht.", "de"),
        ("duly-terms-de", "terms.de.txt", "Die Nutzungsbedingungen von Duly: Invoice Maker & Estimate.", "de"),
        ("duly-privacy-es", "privacy.es.txt", "Cómo trata Duly su información.", "es"),
        ("duly-terms-es", "terms.es.txt", "Los términos de uso de Duly: Invoice Maker & Estimate.", "es"),
    ]:
        title, updated, body = legal_body(LEGAL / src)
        content = f"<h1>{html.escape(title)}</h1>\n<p class=\"updated\">{html.escape(updated)}</p>\n{body}"
        out = ROOT / name / "index.html"
        out.parent.mkdir(exist_ok=True)
        out.write_text(page(title, desc, content, lang), encoding="utf-8")
        wordpress(name, content, lang)
        print("wrote", out.relative_to(ROOT))
    out = ROOT / "duly-help" / "index.html"
    out.parent.mkdir(exist_ok=True)
    out.write_text(page("Help guide", "How to use Duly: invoices, estimates, receipts, payments, iCloud and Premium.", HELP), encoding="utf-8")

    print("wrote", out.relative_to(ROOT))
    out = ROOT / "duly-support" / "index.html"
    out.parent.mkdir(exist_ok=True)
    out.write_text(page("Support", "Help with Duly: Invoice Maker & Estimate.", SUPPORT), encoding="utf-8")

    print("wrote", out.relative_to(ROOT))


if __name__ == "__main__":
    main()
