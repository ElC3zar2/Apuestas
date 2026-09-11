/* 
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
// =========================================================
// BETZONE — interacciones front
// =========================================================

document.addEventListener("DOMContentLoaded", () => {
  initParallax();
  initCardReveal();
});

/**
 * Parallax sutil: los íconos flotantes se mueven levemente
 * en dirección opuesta al cursor dentro del hero.
 */
function initParallax() {
  const hero = document.querySelector(".hero");
  const icons = document.querySelectorAll(".parallax-icon");
  if (!hero || icons.length === 0) return;

  const prefersReducedMotion = window.matchMedia(
    "(prefers-reduced-motion: reduce)"
  ).matches;
  if (prefersReducedMotion) return;

  hero.addEventListener("pointermove", (e) => {
    const { innerWidth, innerHeight } = window;
    const xRatio = (e.clientX / innerWidth - 0.5) * 2; // -1 a 1
    const yRatio = (e.clientY / innerHeight - 0.5) * 2;

    icons.forEach((icon) => {
      const depth = parseFloat(icon.dataset.depth || "10");
      const moveX = -xRatio * depth;
      const moveY = -yRatio * depth;
      icon.style.transform = `translate(${moveX}px, ${moveY}px)`;
    });
  });
}

/**
 * Entrada orquestada de las tarjetas del grid: un único reveal
 * cuando la sección entra en el viewport (no un fade-in repetido
 * por tarjeta al hacer scroll).
 */
function initCardReveal() {
  const grid = document.querySelector(".cards__grid");
  const cards = document.querySelectorAll(".card");
  if (!grid || cards.length === 0) return;

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          cards.forEach((card, i) => {
            card.style.animationDelay = `${i * 0.12}s`;
            card.classList.add("is-visible");
          });
          observer.disconnect();
        }
      });
    },
    { threshold: 0.25 }
  );

  observer.observe(grid);
}


