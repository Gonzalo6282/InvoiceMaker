# Invoice Maker design system ("Ledger Indigo")

Built from Wise's design elements and Stripe's colours, adapted to iOS (SF Pro, Human Interface Guidelines). The rule: **indigo means "do something", lime means "money arrived"**, and nothing else gets a colour.

## Colour tokens (SwiftUI asset catalog names)

| Token | Light | Dark | Use |
|---|---|---|---|
| `ink` | #061B31 | #EEF2F8 | Primary text |
| `ink2` | #50617A | #A7B3C6 | Secondary text |
| `ink3` | #7D8CA3 | #6F7D93 | Placeholders, chevrons |
| `line` | #E3E9F2 | #1E2A3D | Hairlines, card borders |
| `canvas` | #F3F6FA | #05090F | Grouped background |
| `surface` | #FFFFFF | #0F1726 | Rows, cards |
| `brand` | #533AFD | #7B6BFF | The only action colour: buttons, links, selected tab |
| `brandWash` | #ECEAFF | #1C1A45 | Selected chips, "Sent" pill |
| `brandEdge` | #B9B9F9 | #3B3680 | Ghost button border |
| `navy` | #0A2540 | #111D36 | Money hero card, Premium card |
| `paid` / `paidInk` | #9FE870 / #163300 | same | Paid pill, paid amounts, ticks on paywall |
| `due` / `dueWash` | #DF1B41 / #FFE6EB | #FF5D7A / #3A0F19 | Overdue, destructive |
| `warn` / `warnWash` | #B25E09 / #FFF1DC | #F0A646 / #33230C | iCloud off and other warnings |

The invoice paper is always white, in both themes.

## Type (SF Pro; Inter is the web stand-in)

| Style | Size / weight | Tracking | Use |
|---|---|---|---|
| Money display | 40pt Black (900) | -3.5% | "Owed to you" hero |
| Large title | 34pt Heavy (800) | -2.5% | Screen titles |
| Doc number | 28pt Heavy | -2.5% | INV-0012 in the editor |
| Paywall headline | 30pt Black | -3.5% | Paywall |
| Total | 24pt Black | -3% | Totals block |
| Body | 17pt Regular | default | Rows, fields |
| Secondary | 13–15pt Regular | default | Row meta, footers |
| Pill | 12pt Semibold | default | Status tags |

All amounts use `.monospacedDigit()`.

## Shape and spacing

- 4pt grid; 16pt side margins; 22pt between groups.
- Radius: pills and buttons 999 (capsule); grouped lists 14; hero cards 28 (Wise); sheets 14 top corners (system).
- No shadows in the UI. Depth comes from canvas → surface tint plus 1pt hairlines. The invoice paper is the only thing with a shadow, because it is paper.
- Buttons: primary = indigo capsule, 52pt tall; secondary = ghost capsule with lavender border. Always paired the Stripe way.

## Status pills

Draft (grey outline) · Sent (indigo on wash) · Paid (lime on forest) · Overdue (red on pink) · Accepted (forest on pale green) · Invoiced (grey).

## Invoice templates

Clean, Bold, Ledger (free) · Studio, Trades, Classic, Split (Premium). Every template takes the user's brand colour and logo (logo is always "fit", never cropped).

## iPad

Sidebar + list + detail when browsing. When editing in landscape: list + editor (440pt) + live PDF preview. In portrait: editor + live PDF, with a back button. Sheets are 560pt form sheets; the paywall is a 620pt card with everything visible without scrolling. Keyboard: ⌘N new invoice, ⌘S save, ⌘P print.
