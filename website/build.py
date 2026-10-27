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
    text = re.sub(r"(https?://[^\s<,)]+)", r'<a href="\1">\1</a>', text)
    text = re.sub(r"([\w.+-]+@[\w-]+\.[\w.]+)", r'<a href="mailto:\1">\1</a>', text)
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
        elif line.startswith("Last updated") and not updated:
            updated = line
        else:
            out.append(f"<p>{inline(line)}</p>")
    if in_list:
        out.append("</ul>")
    return title, updated, "\n".join(out)


def page(title, description, body):
    return f"""<!doctype html>
<html lang="en">
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
      <a href="../#how">How it works</a>
      <a href="../#features">Features</a>
      <a href="../#plans">Plans</a>
      <a href="../duly-help/">Help</a>
      <a href="../duly-support/">Support</a>
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
    for name, src, desc in [
        ("duly-privacy", "privacy.txt", "How Duly handles your information."),
        ("duly-terms", "terms.txt", "The terms for using Duly: Invoice Maker & Estimate."),
    ]:
        title, updated, body = legal_body(LEGAL / src)
        content = f"<h1>{html.escape(title)}</h1>\n<p class=\"updated\">{html.escape(updated)}</p>\n{body}"
        out = ROOT / name / "index.html"
        out.parent.mkdir(exist_ok=True)
        out.write_text(page(title, desc, content), encoding="utf-8")
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
