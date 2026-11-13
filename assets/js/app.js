/**
 * Yıldırımlar Manav - Ana Uygulama Mantığı (app.js)
 * Ürün listeleme, stok filtreleme, sepet arayüzü ve olay yönetimi.
 */

document.addEventListener('DOMContentLoaded', () => {
  let allProducts = [];
  let activeCategory = 'Tümü';
  let searchQuery = '';

  // DOM Elemanları
  const productGrid = document.getElementById('productGrid');
  const emptyState = document.getElementById('emptyState');
  const categoryContainer = document.getElementById('categoryContainer');
  const activeCategoryTitle = document.getElementById('activeCategoryTitle');
  const productCountInfo = document.getElementById('productCountInfo');
  
  // Arama Elemanları
  const searchInput = document.getElementById('searchInput');
  const mobileSearchInput = document.getElementById('mobileSearchInput');
  const clearSearchBtn = document.getElementById('clearSearchBtn');

  // Sepet Çekmecesi Elemanları
  const openCartBtn = document.getElementById('openCartBtn');
  const closeCartBtn = document.getElementById('closeCartBtn');
  const cartDrawer = document.getElementById('cartDrawer');
  const cartDrawerBackdrop = document.getElementById('cartDrawerBackdrop');
  const cartItemsList = document.getElementById('cartItemsList');
  const emptyCartView = document.getElementById('emptyCartView');
  const cartFooterSection = document.getElementById('cartFooterSection');

  // Sepet Özet Elemanları
  const cartBadge = document.getElementById('cartBadge');
  const cartHeaderTotal = document.getElementById('cartHeaderTotal');
  const cartItemsCountText = document.getElementById('cartItemsCountText');
  const cartSubtotal = document.getElementById('cartSubtotal');
  const cartGrandTotal = document.getElementById('cartGrandTotal');

  // Form Elemanları
  const customerName = document.getElementById('customerName');
  const customerPhone = document.getElementById('customerPhone');
  const customerAddress = document.getElementById('customerAddress');
  const orderNote = document.getElementById('orderNote');
  const submitOrderBtn = document.getElementById('submitOrderBtn');

  // KVKK Modal Elemanları
  const kvkkModalBackdrop = document.getElementById('kvkkModalBackdrop');
  const openKvkkModalBtn = document.getElementById('openKvkkModalBtn');
  const closeKvkkModalBtn = document.getElementById('closeKvkkModalBtn');
  const confirmKvkkModalBtn = document.getElementById('confirmKvkkModalBtn');
  const footerKvkkBtn = document.getElementById('footerKvkkBtn');

  // ----------------------------------------------------
  // 1. ÜRÜN VERİLERİNİ ÇEKME VE BAŞLATMA
  // ----------------------------------------------------
  // SEO: Ürün listesini arama motorları için JSON-LD olarak ekler
  function injectProductSchema(products) {
    const old = document.getElementById('productSchema');
    if (old) old.remove();
    const schema = {
      '@context': 'https://schema.org',
      '@type': 'ItemList',
      itemListElement: products.map((p, i) => ({
        '@type': 'ListItem',
        position: i + 1,
        item: {
          '@type': 'Product',
          name: p.name,
          description: p.description || p.name,
          category: p.category,
          sku: p.sku,
          image: new URL(p.image, location.href).href,
          offers: {
            '@type': 'Offer',
            price: Number(p.price).toFixed(2),
            priceCurrency: 'TRY',
            availability: 'https://schema.org/InStock',
            url: location.origin + '/'
          }
        }
      }))
    };
    const el = document.createElement('script');
    el.type = 'application/ld+json';
    el.id = 'productSchema';
    el.textContent = JSON.stringify(schema);
    document.head.appendChild(el);
  }

  async function loadProducts() {
    try {
      // Önbellek engellemek için anlık zaman damgası eklenir
      const res = await fetch(`data/products.json?v=${Date.now()}`);
      if (!res.ok) throw new Error('Ürünler yüklenemedi');
      
      const rawProducts = await res.json();

      // PRD KURALI: Stok adedi 0 veya daha az olan ürünler vitrinde GÖSTERİLMEZ
      allProducts = rawProducts.filter(p => Number(p.stock) > 0);

      injectProductSchema(allProducts);
      renderCategories();
      renderProducts();
      updateCartUI(window.cart.getSummary());

      if (window.lucide) window.lucide.createIcons();
    } catch (err) {
      console.error('Ürün yükleme hatası:', err);
      productGrid.innerHTML = `
        <div class="col-span-full text-center py-12 text-stone-500">
          <p class="font-bold text-base text-rose-600">Ürün listesi yüklenemedi.</p>
          <p class="text-xs mt-1">Lütfen data/products.json dosyasını kontrol edin.</p>
        </div>
      `;
    }
  }

  // ----------------------------------------------------
  // 2. KATEGORİLERİ RENDER ETME
  // ----------------------------------------------------
  function renderCategories() {
    const categories = ['Tümü', ...new Set(allProducts.map(p => p.category))];

    categoryContainer.innerHTML = categories.map(cat => {
      const isSelected = cat === activeCategory;
      const count = cat === 'Tümü' 
        ? allProducts.length 
        : allProducts.filter(p => p.category === cat).length;

      return `
        <button 
          data-category="${cat}"
          class="category-btn flex-shrink-0 px-4 py-2 rounded-2xl text-xs sm:text-sm font-semibold transition-all flex items-center gap-2 ${
            isSelected 
              ? 'bg-brand-600 text-white shadow-md shadow-brand-600/25' 
              : 'bg-stone-100 text-stone-600 hover:bg-stone-200'
          }"
        >
          <span>${cat}</span>
          <span class="text-[11px] px-1.5 py-0.5 rounded-full ${
            isSelected ? 'bg-white/20 text-white' : 'bg-stone-200 text-stone-500'
          }">${count}</span>
        </button>
      `;
    }).join('');

    // Kategori tıklama olayları
    categoryContainer.querySelectorAll('.category-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        activeCategory = btn.getAttribute('data-category');
        renderCategories();
        renderProducts();
      });
    });
  }

  // ----------------------------------------------------
  // 3. ÜRÜN KARTLARINI RENDER ETME
  // ----------------------------------------------------
  function renderProducts() {
    // Filtreleme: Kategori + Arama
    const filtered = allProducts.filter(p => {
      const matchCategory = activeCategory === 'Tümü' || p.category === activeCategory;
      const matchSearch = searchQuery === '' || 
        p.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        p.category.toLowerCase().includes(searchQuery.toLowerCase()) ||
        (p.description && p.description.toLowerCase().includes(searchQuery.toLowerCase()));
      return matchCategory && matchSearch;
    });

    // Başlık ve sayaç güncelle
    activeCategoryTitle.textContent = activeCategory === 'Tümü' ? 'Tüm Taze Ürünler' : activeCategory;
    productCountInfo.textContent = `${filtered.length} taze ürün listeleniyor`;

    if (filtered.length === 0) {
      productGrid.innerHTML = '';
      emptyState.classList.remove('hidden');
      return;
    }

    emptyState.classList.add('hidden');

    const cartItems = window.cart.getItems();

    productGrid.innerHTML = filtered.map(p => {
      const cartItem = cartItems.find(i => i.sku === p.sku);
      const inCartQty = cartItem ? cartItem.quantity : 0;
      const isLowStock = p.stock <= 15;

      return `
        <div class="product-card bg-white rounded-3xl border border-stone-200/80 shadow-sm hover:shadow-xl transition-all duration-300 p-3.5 sm:p-4 flex flex-col justify-between group overflow-hidden">
          
          <div>
            <!-- Resim Alanı & Rozetler -->
            <div class="relative w-full aspect-square rounded-2xl bg-stone-100 overflow-hidden mb-3">
              <img 
                src="${p.image || `assets/images/products/${p.sku}.svg`}" 
                alt="${p.name}" 
                class="product-card-img w-full h-full object-cover"
                loading="lazy"
                onerror="if (!this.dataset.triedSvg) { this.dataset.triedSvg = 'true'; this.src = 'assets/images/products/${p.sku}.svg'; } else { this.onerror = null; this.src = 'assets/images/products/placeholder.svg'; }"
              >

              <!-- Kategori Rozeti -->
              <span class="absolute top-2.5 left-2.5 bg-white/90 backdrop-blur-md text-stone-700 font-bold text-[10px] px-2.5 py-1 rounded-full shadow-sm">
                ${p.category}
              </span>

              <!-- Düşük Stok Rozeti -->
              ${isLowStock ? `
                <span class="absolute bottom-2.5 left-2.5 bg-amber-500 text-white font-black text-[10px] px-2 py-0.5 rounded-md shadow-sm">
                  Son ${p.stock} ${p.unit}!
                </span>
              ` : ''}

              <!-- Sepette Varsa Belirteç -->
              ${inCartQty > 0 ? `
                <span class="absolute top-2.5 right-2.5 bg-emerald-600 text-white font-black text-[11px] px-2 py-0.5 rounded-full shadow-sm">
                  ✓ ${inCartQty} ${p.unit}
                </span>
              ` : ''}
            </div>

            <!-- Ürün Bilgisi -->
            <h3 class="font-extrabold text-stone-900 text-sm sm:text-base leading-snug group-hover:text-brand-700 transition">
              ${p.name}
            </h3>
            <p class="text-xs text-stone-500 mt-1 line-clamp-2 leading-relaxed">
              ${p.description || 'Taze yerli hasat manav ürünü.'}
            </p>
          </div>

          <!-- Fiyat ve Sepet Butonu -->
          <div class="mt-4 pt-3 border-t border-stone-100 flex items-center justify-between gap-2">
            <div>
              <div class="text-base sm:text-lg font-black text-brand-700">
                ${Number(p.price).toFixed(2)} ₺
              </div>
              <div class="text-[11px] text-stone-400 font-semibold uppercase">
                1 ${p.unit} başına
              </div>
            </div>

            <!-- Sepete Ekle Butonu -->
            <button 
              data-sku="${p.sku}"
              class="add-to-cart-btn bg-stone-900 hover:bg-brand-600 text-white px-3.5 py-2.5 rounded-xl font-bold text-xs flex items-center gap-1.5 shadow-sm active:scale-95 transition-all"
            >
              <i data-lucide="plus" class="w-4 h-4"></i>
              <span class="hidden xs:inline">Ekle</span>
            </button>
          </div>

        </div>
      `;
    }).join('');

    // Sepete Ekle Tıklama Dinleyicileri
    productGrid.querySelectorAll('.add-to-cart-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const sku = btn.getAttribute('data-sku');
        const product = allProducts.find(p => p.sku === sku);
        if (product) {
          window.cart.addItem(product, 1);
          renderProducts(); // Karttaki rozeti güncelle
        }
      });
    });

    if (window.lucide) window.lucide.createIcons();
  }

  // ----------------------------------------------------
  // 4. SEPET ARAYÜZÜ (DRAWER) GÜNCELLEME
  // ----------------------------------------------------
  function updateCartUI(summary) {
    // 1. Header Butonu ve Rozet
    if (summary.totalItemsCount > 0) {
      cartBadge.textContent = summary.totalItemsCount;
      cartBadge.classList.remove('hidden');
      cartBadge.classList.add('badge-bounce');
      setTimeout(() => cartBadge.classList.remove('badge-bounce'), 300);

      cartHeaderTotal.textContent = `${summary.subtotal.toFixed(2)} ₺`;
      cartHeaderTotal.classList.remove('hidden');
    } else {
      cartBadge.classList.add('hidden');
      cartHeaderTotal.classList.add('hidden');
    }

    cartItemsCountText.textContent = `${summary.totalItemsCount} ürün seçildi`;

    // 3. Boş Sepet vs Dolu Sepet
    if (summary.items.length === 0) {
      cartItemsList.classList.add('hidden');
      emptyCartView.classList.remove('hidden');
      cartFooterSection.classList.add('opacity-50', 'pointer-events-none');
    } else {
      cartItemsList.classList.remove('hidden');
      emptyCartView.classList.add('hidden');
      cartFooterSection.classList.remove('opacity-50', 'pointer-events-none');
    }

    // 4. Sepet İtem Listesi Render
    cartItemsList.innerHTML = summary.items.map(item => {
      const lineTotal = (item.price * item.quantity).toFixed(2);
      return `
        <div class="py-3 flex items-center justify-between gap-3">
          <!-- Görsel -->
          <div class="w-14 h-14 rounded-xl bg-stone-100 flex-shrink-0 overflow-hidden border border-stone-200">
            <img 
              src="${item.image || `assets/images/products/${item.sku}.svg`}" 
              alt="${item.name}" 
              class="w-full h-full object-cover"
              onerror="if (!this.dataset.triedSvg) { this.dataset.triedSvg = 'true'; this.src = 'assets/images/products/${item.sku}.svg'; } else { this.onerror = null; this.src = 'assets/images/products/placeholder.svg'; }"
            >
          </div>

          <!-- İsim ve Birim Fiyat -->
          <div class="flex-1 min-w-0">
            <h4 class="font-bold text-xs sm:text-sm text-stone-900 truncate">${item.name}</h4>
            <div class="text-[11px] text-stone-400 font-medium">
              ${item.price.toFixed(2)} ₺ / ${item.unit}
            </div>
            <div class="text-xs font-black text-brand-700 mt-0.5">
              ${lineTotal} ₺
            </div>
          </div>

          <!-- Miktar Butonları -->
          <div class="flex items-center gap-1.5 bg-stone-100 p-1 rounded-xl">
            <button 
              data-sku="${item.sku}" 
              data-delta="-1" 
              class="qty-btn w-6 h-6 rounded-lg bg-white shadow-xs text-stone-700 hover:bg-stone-200 flex items-center justify-center font-bold text-xs"
            >-</button>
            <span class="w-6 text-center font-extrabold text-xs text-stone-800">
              ${item.quantity}
            </span>
            <button 
              data-sku="${item.sku}" 
              data-delta="1" 
              class="qty-btn w-6 h-6 rounded-lg bg-white shadow-xs text-stone-700 hover:bg-stone-200 flex items-center justify-center font-bold text-xs"
            >+</button>
          </div>

          <!-- Sil Butonu -->
          <button 
            data-sku="${item.sku}" 
            class="remove-item-btn text-stone-300 hover:text-rose-500 p-1.5 transition"
            title="Ürünü Sil"
          >
            <i data-lucide="trash-2" class="w-4 h-4"></i>
          </button>
        </div>
      `;
    }).join('');

    // Sepet İçi Miktar Değiştirme Dinleyicileri
    cartItemsList.querySelectorAll('.qty-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const sku = btn.getAttribute('data-sku');
        const delta = parseInt(btn.getAttribute('data-delta'), 10);
        window.cart.updateQuantity(sku, delta);
        renderProducts();
      });
    });

    // Sepet İçi Silme Dinleyicileri
    cartItemsList.querySelectorAll('.remove-item-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const sku = btn.getAttribute('data-sku');
        window.cart.removeItem(sku);
        renderProducts();
      });
    });

    // 5. Toplam Rakamları Güncelle
    cartSubtotal.textContent = `${summary.subtotal.toFixed(2)} ₺`;
    cartGrandTotal.textContent = `${summary.grandTotal.toFixed(2)} ₺`;

    submitOrderBtn.innerHTML = `
      <i data-lucide="message-circle" class="w-5 h-5"></i>
      <span>WhatsApp ile Sipariş Ver (${summary.grandTotal.toFixed(2)} ₺)</span>
    `;

    if (window.lucide) window.lucide.createIcons();
  }

  // ----------------------------------------------------
  // 5. SEPET ÇEKMECESİ AÇ/KAPA OLAYLARI
  // ----------------------------------------------------
  function openCart() {
    cartDrawerBackdrop.classList.remove('opacity-0', 'pointer-events-none');
    cartDrawer.classList.remove('translate-x-full');
    document.body.classList.add('overflow-hidden');
  }

  function closeCart() {
    cartDrawerBackdrop.classList.add('opacity-0', 'pointer-events-none');
    cartDrawer.classList.add('translate-x-full');
    document.body.classList.remove('overflow-hidden');
  }

  openCartBtn.addEventListener('click', openCart);
  closeCartBtn.addEventListener('click', closeCart);
  cartDrawerBackdrop.addEventListener('click', closeCart);

  // Cart Updated Custom Event Dinleyicisi
  window.addEventListener('cartUpdated', (e) => {
    updateCartUI(e.detail);
  });

  // ----------------------------------------------------
  // 6. ARAMA İŞLEMLERİ
  // ----------------------------------------------------
  function handleSearch(val) {
    searchQuery = val.trim();
    if (clearSearchBtn) {
      if (searchQuery.length > 0) {
        clearSearchBtn.classList.remove('hidden');
      } else {
        clearSearchBtn.classList.add('hidden');
      }
    }
    renderProducts();
  }

  if (searchInput) {
    searchInput.addEventListener('input', (e) => {
      if (mobileSearchInput) mobileSearchInput.value = e.target.value;
      handleSearch(e.target.value);
    });
  }

  if (mobileSearchInput) {
    mobileSearchInput.addEventListener('input', (e) => {
      if (searchInput) searchInput.value = e.target.value;
      handleSearch(e.target.value);
    });
  }

  if (clearSearchBtn) {
    clearSearchBtn.addEventListener('click', () => {
      if (searchInput) searchInput.value = '';
      if (mobileSearchInput) mobileSearchInput.value = '';
      handleSearch('');
    });
  }

  const resetFilterBtn = document.getElementById('resetFilterBtn');
  if (resetFilterBtn) {
    resetFilterBtn.addEventListener('click', () => {
      activeCategory = 'Tümü';
      handleSearch('');
      renderCategories();
    });
  }

  // ----------------------------------------------------
  // 7. SİPARİŞİ TAMAMLAMA (WHATSAPP TETİKLEME)
  // ----------------------------------------------------
  submitOrderBtn.addEventListener('click', () => {
    const customer = {
      name: customerName.value,
      phone: customerPhone.value,
      address: customerAddress.value,
      note: orderNote.value
    };

    window.whatsAppOrder.processOrder(customer);
  });

  // Telefon Numarası Formatlama Kolaylığı
  customerPhone.addEventListener('input', (e) => {
    let num = e.target.value.replace(/\D/g, '');
    if (num.startsWith('90')) num = num.substring(2);
    if (num.length > 11) num = num.substring(0, 11);
    e.target.value = num;
  });

  // ----------------------------------------------------
  // 8. KVKK MODAL OLAYLARI
  // ----------------------------------------------------
  function openKvkkModal() {
    kvkkModalBackdrop.classList.remove('opacity-0', 'pointer-events-none');
  }
  function closeKvkkModal() {
    kvkkModalBackdrop.classList.add('opacity-0', 'pointer-events-none');
  }

  if (openKvkkModalBtn) openKvkkModalBtn.addEventListener('click', openKvkkModal);
  if (footerKvkkBtn) footerKvkkBtn.addEventListener('click', openKvkkModal);
  if (closeKvkkModalBtn) closeKvkkModalBtn.addEventListener('click', closeKvkkModal);
  if (confirmKvkkModalBtn) confirmKvkkModalBtn.addEventListener('click', closeKvkkModal);
  if (kvkkModalBackdrop) {
    kvkkModalBackdrop.addEventListener('click', (e) => {
      if (e.target === kvkkModalBackdrop) closeKvkkModal();
    });
  }

  // Başlat
  loadProducts();
});
