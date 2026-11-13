/**
 * Yıldırımlar Manav - WhatsApp & Sipariş Dağıtım Modülü (whatsapp.js)
 * Mobil cihazlarda doğrudan WhatsApp uygulamasını, masaüstünde QR kod modalını açar.
 */

const WHATSAPP_PHONE = '905384511596'; // İşletme WhatsApp Hattı (90 formatında)

class WhatsAppOrderService {
  constructor() {
    this.currentOrderText = '';
    this.currentWhatsAppUrl = '';
    this.initModalEvents();
  }

  // Mobil cihaz kontrolü
  isMobile() {
    return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent) || window.innerWidth < 768;
  }

  // Manav sipariş metnini şablonla oluştur
  buildMessage(summary, customer) {
    const dateStr = new Date().toLocaleString('tr-TR', { 
      day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' 
    });
    const orderNo = 'SP-' + Math.floor(1000 + Math.random() * 9000);

    let lines = [
      `🥦 *YILDIRIMLAR MANAV - YENİ SİPARİŞ*`,
      `🔖 *Sipariş No:* #${orderNo} | 🕒 ${dateStr}`,
      `--------------------------------------`
    ];

    // Ürün dökümü
    summary.items.forEach(item => {
      const lineTotal = (item.price * item.quantity).toFixed(2);
      lines.push(`• ${item.quantity} ${item.unit} x ${item.name} (${lineTotal} ₺)`);
    });

    lines.push(`--------------------------------------`);
    lines.push(`💵 *Ara Toplam:* ${summary.subtotal.toFixed(2)} ₺`);
    lines.push(`💰 *GENEL TOPLAM:* ${summary.grandTotal.toFixed(2)} ₺`);
    lines.push(``);
    lines.push(`📍 *Müşteri & Teslimat Bilgileri:*`);
    lines.push(`👤 *Ad Soyad:* ${customer.name.trim()}`);
    lines.push(`📞 *Telefon:* ${customer.phone.trim()}`);
    lines.push(`🏠 *Adres:* ${customer.address.trim()}`);
    if (customer.note && customer.note.trim()) {
      lines.push(`📝 *Sipariş Notu:* ${customer.note.trim()}`);
    }
    lines.push(``);
    lines.push(`ℹ️ *Ödeme:* Kapıda Nakit / Kredi Kartı`);

    return lines.join('\n');
  }

  // Siparişi gönder
  processOrder(customer) {
    const summary = window.cart.getSummary();

    if (!summary.items || summary.items.length === 0) {
      window.cart.showToast('Sepetiniz boş, lütfen ürün ekleyin.', 'error');
      return;
    }

    // Form doğrulamaları
    if (!customer.name || customer.name.trim().length < 3) {
      window.cart.showToast('Lütfen adınızı ve soyadınızı eksiksiz girin.', 'warning');
      return;
    }
    if (!customer.phone || customer.phone.trim().length < 10) {
      window.cart.showToast('Lütfen geçerli bir telefon numarası girin.', 'warning');
      return;
    }
    if (!customer.address || customer.address.trim().length < 8) {
      window.cart.showToast('Lütfen açık teslimat adresinizi girin.', 'warning');
      return;
    }

    const message = this.buildMessage(summary, customer);
    this.currentOrderText = message;
    const encodedText = encodeURIComponent(message);
    const waUrl = `https://wa.me/${WHATSAPP_PHONE}?text=${encodedText}`;
    this.currentWhatsAppUrl = waUrl;

    if (this.isMobile()) {
      // Doğrudan mobil WhatsApp uygulamasını aç
      window.location.href = waUrl;
      window.cart.showToast('WhatsApp uygulamasına yönlendiriliyorsunuz...', 'success');
    } else {
      // Masaüstü: Dinamik QR Kod ve WhatsApp Web Seçenekleri Modalını Aç
      this.openQrModal(waUrl);
    }
  }

  // Masaüstü QR Kod Modalını aç
  openQrModal(waUrl) {
    const modal = document.getElementById('qrModalBackdrop');
    const qrTarget = document.getElementById('qrCodeTarget');
    const openWebBtn = document.getElementById('openWhatsAppWebBtn');

    if (!modal || !qrTarget) return;

    // QR kodu temizle ve yeniden çiz
    qrTarget.innerHTML = '';
    if (window.QRCode) {
      new QRCode(qrTarget, {
        text: waUrl,
        width: 190,
        height: 190,
        colorDark: '#064e3b',
        colorLight: '#ffffff',
        correctLevel: QRCode.CorrectLevel.M
      });
    } else {
      qrTarget.innerHTML = '<p class="text-xs text-stone-400">QR Kod yüklenemedi</p>';
    }

    // WhatsApp Web bağlantısını güncelle
    const encodedText = encodeURIComponent(this.currentOrderText);
    const webUrl = `https://web.whatsapp.com/send?phone=${WHATSAPP_PHONE}&text=${encodedText}`;
    if (openWebBtn) {
      openWebBtn.href = webUrl;
    }

    // Modal'ı göster
    modal.classList.remove('opacity-0', 'pointer-events-none');
    document.getElementById('qrModalBox').classList.remove('scale-95');
  }

  // Masaüstü modalını kapat
  closeQrModal() {
    const modal = document.getElementById('qrModalBackdrop');
    if (!modal) return;
    modal.classList.add('opacity-0', 'pointer-events-none');
    document.getElementById('qrModalBox').classList.add('scale-95');
  }

  // Modal buton olaylarını bağla
  initModalEvents() {
    document.addEventListener('DOMContentLoaded', () => {
      const closeBtn = document.getElementById('closeQrModalBtn');
      const backdrop = document.getElementById('qrModalBackdrop');
      const copyBtn = document.getElementById('copyOrderTextBtn');

      if (closeBtn) closeBtn.addEventListener('click', () => this.closeQrModal());
      if (backdrop) {
        backdrop.addEventListener('click', (e) => {
          if (e.target === backdrop) this.closeQrModal();
        });
      }

      if (copyBtn) {
        copyBtn.addEventListener('click', () => {
          if (!this.currentOrderText) return;
          navigator.clipboard.writeText(this.currentOrderText).then(() => {
            window.cart.showToast('Sipariş metni panoya kopyalandı!', 'success');
          }).catch(() => {
            window.cart.showToast('Kopyalama başarısız oldu.', 'error');
          });
        });
      }
    });
  }
}

window.whatsAppOrder = new WhatsAppOrderService();
