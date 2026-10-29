const fs = require('fs');
const path = require('path');

const products = [
  { sku: "SEB-001", name: "Çanakkale Domates", emoji: "🍅", bg: "#FEE2E2", color: "#DC2626" },
  { sku: "SEB-002", name: "Çengelköy Salatalık", emoji: "🥒", bg: "#DCFCE7", color: "#16A34A" },
  { sku: "SEB-003", name: "Köy Biberi", emoji: "🫑", bg: "#FEF9C3", color: "#CA8A04" },
  { sku: "SEB-004", name: "Ödemiş Patates", emoji: "🥔", bg: "#FEF3C7", color: "#D97706" },
  { sku: "SEB-005", name: "Amasya Soğan", emoji: "🧅", bg: "#FFEDD5", color: "#EA580C" },
  { sku: "MEY-001", name: "Amasya Elması", emoji: "🍎", bg: "#FEE2E2", color: "#E11D48" },
  { sku: "MEY-002", name: "İthal Muz", emoji: "🍌", bg: "#FEF08A", color: "#CA8A04" },
  { sku: "MEY-003", name: "Tarla Çileği", emoji: "🍓", bg: "#FFE4E6", color: "#E11D48" },
  { sku: "MEY-004", name: "Deveci Armudu", emoji: "🍐", bg: "#ECFCCB", color: "#65A30D" },
  { sku: "YES-001", name: "Köy Maydanozu", emoji: "🌿", bg: "#DCFCE7", color: "#15803D" },
  { sku: "YES-002", name: "Kıvırcık Marul", emoji: "🥬", bg: "#D1FAE5", color: "#059669" },
  { sku: "YES-003", name: "Bahçe Rokası", emoji: "🌱", bg: "#ECFCCB", color: "#4D7C0F" },
  { sku: "YES-004", name: "Taze Nane", emoji: "🍃", bg: "#CCFBF1", color: "#0F766E" },
  { sku: "NAR-001", name: "Finike Portakal", emoji: "🍊", bg: "#FFEDD5", color: "#F97316" },
  { sku: "NAR-002", name: "Yatak Limon", emoji: "🍋", bg: "#FEF9C3", color: "#EAB308" },
  { sku: "NAR-003", name: "İthal Avokado", emoji: "🥑", bg: "#ECFCCB", color: "#4D7C0F" },
  { sku: "placeholder", name: "Yıldırımlar Manav", emoji: "🛒", bg: "#F3F4F6", color: "#4B5563" }
];

const targetDir = path.join(__dirname, 'assets', 'images', 'products');

products.forEach(p => {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600" viewBox="0 0 600 600">
  <defs>
    <radialGradient id="grad-${p.sku}" cx="50%" cy="40%" r="60%">
      <stop offset="0%" stop-color="#ffffff" stop-opacity="0.8"/>
      <stop offset="100%" stop-color="${p.bg}"/>
    </radialGradient>
  </defs>
  <rect width="600" height="600" fill="${p.bg}"/>
  <circle cx="300" cy="270" r="190" fill="url(#grad-${p.sku})"/>
  <text x="300" y="320" font-size="140" text-anchor="middle" dominant-baseline="middle" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif">${p.emoji}</text>
  <rect x="50" y="490" width="500" height="60" rx="30" fill="${p.color}" fill-opacity="0.15"/>
  <text x="300" y="528" font-size="28" font-weight="700" fill="${p.color}" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif">${p.name}</text>
  <text x="560" y="45" font-size="20" font-weight="600" fill="#9CA3AF" text-anchor="end" font-family="monospace">${p.sku}</text>
</svg>`;

  fs.writeFileSync(path.join(targetDir, `${p.sku}.svg`), svg);
});

console.log('SVGs created successfully.');
