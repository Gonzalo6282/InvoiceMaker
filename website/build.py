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
      <ul><li><a href="../duly-support/">Support</a></li><li><a href="mailto:{EMAIL}">{EMAIL}</a></li></ul>
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
    out = ROOT / "duly-support" / "index.html"
    out.parent.mkdir(exist_ok=True)
    out.write_text(page("Support", "Help with Duly: Invoice Maker & Estimate.", SUPPORT), encoding="utf-8")
    print("wrote", out.relative_to(ROOT))


if __name__ == "__main__":
    main()
