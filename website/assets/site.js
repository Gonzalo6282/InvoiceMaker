// Duly website: the self-writing invoice, the phone that follows the steps,
// and the owed counter. Everything shows its final state with reduced motion.
(() => {
  const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const money = (v) => "$" + v.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });

  // Header hairline once the page scrolls.
  const header = document.querySelector(".site-header");
  if (header) {
    const onScroll = () => header.classList.toggle("scrolled", scrollY > 8);
    addEventListener("scroll", onScroll, { passive: true });
    onScroll();
  }

  // Count a number up from zero.
  const countUp = (el, to, ms) => {
    if (reduce) { el.textContent = money(to); return; }
    const start = performance.now();
    const tick = (t) => {
      const p = Math.min(1, (t - start) / ms);
      const eased = 1 - Math.pow(1 - p, 3);
      el.textContent = money(to * eased);
      if (p < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  };

  // The invoice that writes itself: logo, client, lines, total, sent, paid.
  const stage = document.getElementById("stage");
  if (stage) {
    const n = (k) => stage.querySelector(`[data-n="${k}"]`);
    const paper = stage.querySelector(".paper");
    const status = n("status");
    const replay = document.getElementById("replay");
    const timers = [];
    const at = (ms, fn) => timers.push(setTimeout(fn, ms));

    const reset = () => {
      timers.splice(0).forEach(clearTimeout);
      paper.classList.remove("go");
      stage.querySelectorAll(".on").forEach((el) => el.classList.remove("on"));
      status.className = "status";
      status.textContent = "Draft";
      ["sub", "tax", "total"].forEach((k) => (n(k).textContent = "$0.00"));
      void paper.offsetWidth;
    };

    const play = () => {
      reset();
      replay.hidden = true;
      paper.classList.add("go");
      at(250, () => n("logo").classList.add("on"));
      at(650, () => n("client").classList.add("on"));
      at(1500, () => n("addr").classList.add("on"));
      at(1900, () => n("l1").classList.add("on"));
      at(2300, () => n("l2").classList.add("on"));
      at(2700, () => {
        countUp(n("sub"), 1425, 700);
        countUp(n("tax"), 126.47, 700);
        countUp(n("total"), 1551.47, 900);
      });
      at(3500, () => n("pay").classList.add("on"));
      at(4100, () => { status.className = "status sent"; status.textContent = "Sent"; });
      at(5300, () => n("notify").classList.add("on"));
      at(5700, () => {
        n("stamp").classList.add("on");
        status.className = "status paid";
        status.textContent = "Paid";
      });
      at(6600, () => (replay.hidden = false));
    };

    if (reduce) {
      stage.classList.add("static");
      status.className = "status paid";
      status.textContent = "Paid";
      n("notify").classList.add("on");
    } else {
      play();
      replay.addEventListener("click", play);
    }
  }

  // The phone follows the step being read.
  const steps = [...document.querySelectorAll(".steps li")];
  const shots = [...document.querySelectorAll(".phone .screen img")];
  if (steps.length && shots.length) {
    const io = new IntersectionObserver((entries) => {
      entries.forEach((e) => {
        if (!e.isIntersecting) return;
        const i = Number(e.target.dataset.shot);
        steps.forEach((s, j) => s.classList.toggle("active", j === i));
        shots.forEach((img, j) => img.classList.toggle("show", j === i));
      });
    }, { rootMargin: "-45% 0px -45% 0px" });
    steps.forEach((s) => io.observe(s));
  }

  // Owed counter counts up once when it comes into view.
  const owed = document.getElementById("owed");
  if (owed) {
    const io = new IntersectionObserver((entries) => {
      if (!entries[0].isIntersecting) return;
      owed.querySelectorAll("[data-count]").forEach((el, i) => countUp(el, Number(el.dataset.count), 1100 + i * 150));
      io.disconnect();
    }, { threshold: 0.5 });
    io.observe(owed);
  }
})();
