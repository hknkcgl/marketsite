/**
 * Yıldırımlar Manav - Sepet Yönetim Modülü (cart.js)
 * Tamamen tarayıcı tarafında (localStorage) çalışan hafif sepet mantığı.
 */

const CART_STORAGE_KEY = 'yildirimlar_manav_cart_v1';

class CartManager {
  constructor() {
    this.items = this.loadCart();
  }

  // LocalStorage'dan sepeti yükle
  loadCart() {
    try {
      const data = localStorage.getItem(CART_STORAGE_KEY);
      return data ? JSON.parse(data) : [];
    } catch (e) {
      console.error('Sepet yüklenirken hata:', e);
      return [];
    }
  }

  // LocalStorage'a kaydet ve olay fırlat
  saveCart() {
    try {
      localStorage.setItem(CART_STORAGE_KEY, JSON.stringify(this.items));
      window.dispatchEvent(new CustomEvent('cartUpdated', { detail: this.getSummary() }));
    } catch (e) {
      console.error('Sepet kaydedilirken hata:', e);
    }
  }

  // Sepetteki tüm öğeleri getir
  getItems() {
    return this.items;
  }

  // Ürünü sepete ekle
  addItem(product, quantity = 1) {
    if (!product || product.stock <= 0) {
      this.showToast('Bu ürünün stoğu tükenmiştir.', 'error');
      return false;
    }

    const existingIndex = this.items.findIndex(item => item.sku === product.sku);

    if (existingIndex > -1) {
      const currentItem = this.items[existingIndex];
      const newQuantity = currentItem.quantity + quantity;

      if (newQuantity > product.stock) {
        this.showToast(`Maksimum stok adedine ulaştınız (Kalan: ${product.stock} ${product.unit}).`, 'warning');
        currentItem.quantity = product.stock;
      } else {
        currentItem.quantity = newQuantity;
        this.showToast(`${product.name} sepetinizde güncellendi.`, 'success');
      }
    } else {
      const initialQty = Math.min(quantity, product.stock);
      this.items.push({
        sku: product.sku,
        name: product.name,
        price: Number(product.price),
        unit: product.unit || 'adet',
        stock: Number(product.stock),
        image: product.image,
        quantity: initialQty
      });
      this.showToast(`${product.name} sepete eklendi!`, 'success');
    }

    this.saveCart();
    return true;
  }

  // Miktar artır / azalt (+1, -1)
  updateQuantity(sku, delta) {
    const item = this.items.find(i => i.sku === sku);
    if (!item) return;

    const newQty = item.quantity + delta;

    if (newQty <= 0) {
      this.removeItem(sku);
      return;
    }

    if (newQty > item.stock) {
      this.showToast(`Maksimum stok adedi: ${item.stock} ${item.unit}`, 'warning');
      item.quantity = item.stock;
    } else {
      item.quantity = newQty;
    }

    this.saveCart();
  }

  // Ürünü sepetten tamamen sil
  removeItem(sku) {
    const item = this.items.find(i => i.sku === sku);
    this.items = this.items.filter(i => i.sku !== sku);
    this.saveCart();
    if (item) {
      this.showToast(`${item.name} sepetten çıkarıldı.`, 'info');
    }
  }

  // Sepeti boşalt
  clearCart() {
    this.items = [];
    this.saveCart();
  }

  // Toplam hesaplamaları
  getSummary() {
    const totalItemsCount = this.items.reduce((sum, item) => sum + item.quantity, 0);
    const subtotal = this.items.reduce((sum, item) => sum + (item.price * item.quantity), 0);
    
    const grandTotal = subtotal;

    return {
      items: this.items,
      totalItemsCount,
      subtotal,
      grandTotal
    };
  }

  // Modern Toast Bildirimi
  showToast(message, type = 'info') {
    const container = document.getElementById('toastContainer');
    if (!container) return;

    const toast = document.createElement('div');
    toast.className = `toast-enter pointer-events-auto flex items-center gap-2 px-4 py-3 rounded-2xl shadow-lg text-xs font-semibold text-white transition-all duration-300 ${
      type === 'success' ? 'bg-emerald-600' :
      type === 'warning' ? 'bg-amber-600' :
      type === 'error' ? 'bg-rose-600' : 'bg-stone-800'
    }`;

    const iconName = type === 'success' ? 'check-circle' :
                     type === 'warning' ? 'alert-triangle' :
                     type === 'error' ? 'alert-circle' : 'info';

    toast.innerHTML = `
      <i data-lucide="${iconName}" class="w-4 h-4 flex-shrink-0"></i>
      <span>${message}</span>
    `;

    container.appendChild(toast);
    if (window.lucide) window.lucide.createIcons();

    setTimeout(() => {
      toast.style.opacity = '0';
      toast.style.transform = 'translateY(10px)';
      setTimeout(() => toast.remove(), 300);
    }, 2800);
  }
}

// Global olarak tekil (singleton) nesne oluştur
window.cart = new CartManager();
