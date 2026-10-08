import { HeuristicReceiptParserJS } from './parser.js';
import { renderDonutChart, renderWeeklyBarChart, CATEGORY_COLORS } from './canvas_charts.js';
import { getStoredTransactions, saveTransaction, deleteTransaction } from './db.js';
import { saveTransactionToFirebase, getTransactionsFromFirebase, deleteTransactionFromFirebase, uploadReceiptImageToFirebase } from './firebase.js';

let transactions = getStoredTransactions();
let activeCategoryFilter = 'all';
let searchQuery = '';
let selectedDonutCategory = null;
let selectedBarIndex = null;

const SAMPLE_TEXTS = {
  winmart: [
    'SIÊU THỊ WINMART+ NGUYỄN VĂN CỪ',
    'Địa chỉ: 123 Nguyễn Văn Cừ, Q.5',
    'Ngày: 15/05/2026 14:30',
    '1. Sữa tươi Vinamilk 1L - 38.000',
    '2. Bánh mì Sandwich - 22.000',
    'TỔNG CỘNG: 60.000 VNĐ',
    'TIỀN MẶT: 100.000'
  ],
  highlands: [
    'HIGHLANDS COFFEE',
    'Mã HD: HD98821',
    'Date: 2026/06/20',
    'Phin Sữa Đá L - 49.000đ',
    'Bánh Mì Thịt Nướng - 35.000đ',
    'THÀNH TIỀN: 84.000',
    'CẢM ƠN QUÝ KHÁCH'
  ],
  fahasa: [
    'NHÀ SÁCH FAHASA NGUYỄN HUỆ',
    'MST: 0300441239',
    'Ngày lập: 10/04/2026',
    'Sách Flutter for Beginners - 185.000',
    'Bút chì 2B - 15.000',
    'TỔNG TIỀN: 200.000đ'
  ]
};

document.addEventListener('DOMContentLoaded', () => {
  initApp();
});

function initApp() {
  renderCharts();
  renderTransactionsList();
  setupEventListeners();
}

function calculateCategoryTotals() {
  const totals = {
    'Thực phẩm': 0,
    'Học tập': 0,
    'Du lịch & Di chuyển': 0,
    'Thiết bị & Đồ dùng': 0,
    'Giải trí': 0,
    'Khác': 0
  };

  transactions.forEach(t => {
    totals[t.category] = (totals[t.category] || 0) + t.amount;
  });

  return totals;
}

function prepareWeeklyBarData() {
  const dayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  const now = new Date();
  const result = [];

  for (let i = 6; i >= 0; i--) {
    const d = new Date(now);
    d.setDate(d.getDate() - i);
    const dateStr = d.toISOString().split('T')[0];

    const daySum = transactions
      .filter(t => t.date === dateStr)
      .reduce((sum, t) => sum + t.amount, 0);

    const dayIdx = (d.getDay() + 6) % 7; // Convert Sun=0 to Mon=0
    result.add ? result.add() : result.push({
      dayLabel: dayLabels[dayIdx],
      amount: daySum,
      dateStr
    });
  }

  return result;
}

function renderCharts() {
  const donutCanvas = document.getElementById('donutChartCanvas');
  const barCanvas = document.getElementById('barChartCanvas');

  const catTotals = calculateCategoryTotals();
  renderDonutChart(donutCanvas, catTotals, selectedDonutCategory, (cat) => {
    selectedDonutCategory = cat;
    renderCharts();
  });

  const weeklyData = prepareWeeklyBarData();
  renderWeeklyBarChart(barCanvas, weeklyData, selectedBarIndex, (idx) => {
    selectedBarIndex = idx;
    renderCharts();
  });
}

let currentImageDataUrl = null;

function renderTransactionsList() {
  const container = document.getElementById('txListContainer');
  container.innerHTML = '';

  const filtered = transactions.filter(t => {
    const matchesCat = (activeCategoryFilter === 'all' || t.category === activeCategoryFilter);
    const matchesSearch = !searchQuery ||
      t.merchantName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (t.note && t.note.toLowerCase().includes(searchQuery.toLowerCase()));
    return matchesCat && matchesSearch;
  });

  if (filtered.length === 0) {
    container.innerHTML = `<p style="text-align: center; color: var(--text-muted); padding: 24px;">Không tìm thấy giao dịch nào</p>`;
    return;
  }

  filtered.forEach(t => {
    const item = document.createElement('div');
    item.className = 'tx-item';
    const catColor = CATEGORY_COLORS[t.category] || '#78909C';

    item.innerHTML = `
      <div class="tx-info">
        <div class="tx-icon" style="background: ${catColor}25; color: ${catColor}; font-weight: bold;">
          ${t.category.charAt(0)}
        </div>
        <div class="tx-details">
          <h4>${t.merchantName}</h4>
          <p>${t.date} ${t.note ? `• ${t.note}` : ''}</p>
        </div>
      </div>
      <div style="display: flex; align-items: center; gap: 12px;">
        <span class="tx-amount">-${t.amount.toLocaleString('vi-VN')} đ</span>
        ${t.imagePath ? `<button class="view-img-btn" data-id="${t.id}" style="background: rgba(108, 92, 231, 0.2); border: none; color: #6C5CE7; padding: 4px 8px; border-radius: 6px; cursor: pointer; font-size: 0.75rem;">📷 Xem ảnh</button>` : ''}
        <button class="delete-btn" data-id="${t.id}" style="background: none; border: none; color: #EF4444; cursor: pointer; font-size: 1.1rem;">🗑️</button>
      </div>
    `;

    container.appendChild(item);
  });

  // Attach delete buttons
  document.querySelectorAll('.delete-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
      const id = parseInt(e.currentTarget.getAttribute('data-id'));
      deleteTransaction(id);
      transactions = getStoredTransactions();
      renderCharts();
      renderTransactionsList();
    });
  });

  // Attach view image buttons
  document.querySelectorAll('.view-img-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
      const id = parseInt(e.currentTarget.getAttribute('data-id'));
      const tx = transactions.find(t => t.id === id);
      if (tx && tx.imagePath) {
        document.getElementById('fullSizeReceiptImg').src = tx.imagePath;
        document.getElementById('imageViewerModal').classList.add('active');
      }
    });
  });
}

function setupEventListeners() {
  // Category Filter Chips
  document.querySelectorAll('#categoryChips .chip').forEach(chip => {
    chip.addEventListener('click', (e) => {
      document.querySelectorAll('#categoryChips .chip').forEach(c => c.classList.remove('active'));
      e.target.classList.add('active');
      activeCategoryFilter = e.target.getAttribute('data-cat');
      renderTransactionsList();
    });
  });

  // Search input
  document.getElementById('searchInput').addEventListener('input', (e) => {
    searchQuery = e.target.value.trim();
    renderTransactionsList();
  });

  // Modal controls
  const modal = document.getElementById('scanModal');
  document.getElementById('openScanModalBtn').addEventListener('click', () => {
    modal.classList.add('active');
  });

  document.getElementById('closeModalBtn').addEventListener('click', () => {
    modal.classList.remove('active');
  });

  const imgModal = document.getElementById('imageViewerModal');
  const closeImgModalBtn = document.getElementById('closeImageModalBtn');
  if (closeImgModalBtn) {
    closeImgModalBtn.addEventListener('click', () => {
      imgModal.classList.remove('active');
    });
  }

  // Sample Receipt Buttons
  document.querySelectorAll('.sample-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
      const sampleKey = e.target.getAttribute('data-sample');
      const lines = SAMPLE_TEXTS[sampleKey];
      runHeuristicOCR(lines);
    });
  });

  // Camera Direct Capture Button
  document.getElementById('cameraBtn').addEventListener('click', () => {
    document.getElementById('cameraInput').click();
  });

  // Upload custom file from Gallery/Disk
  document.getElementById('uploadBtn').addEventListener('click', () => {
    document.getElementById('imageInput').click();
  });

  const handleImageFileSelection = async (file) => {
    if (!file) return;

    // Convert image file to local DataURL for persistent storage in app
    const reader = new FileReader();
    reader.onload = (e) => {
      currentImageDataUrl = e.target.result;
    };
    reader.readAsDataURL(file);

    // Preview image in modal frame
    const previewImg = document.getElementById('previewImg');
    const scanPlaceholderText = document.getElementById('scanPlaceholderText');
    previewImg.src = URL.createObjectURL(file);
    previewImg.style.display = 'block';
    if (scanPlaceholderText) scanPlaceholderText.style.display = 'none';

    document.getElementById('ocrLoading').style.display = 'block';

    try {
      if (window.Tesseract) {
        const worker = await window.Tesseract.createWorker('vie');
        const ret = await worker.recognize(file);
        await worker.terminate();
        const lines = ret.data.text.split('\n');
        runHeuristicOCR(lines);
      } else {
        runHeuristicOCR(SAMPLE_TEXTS.winmart);
      }
    } catch (err) {
      runHeuristicOCR(SAMPLE_TEXTS.winmart);
    } finally {
      document.getElementById('ocrLoading').style.display = 'none';
    }
  };

  document.getElementById('cameraInput').addEventListener('change', (e) => {
    handleImageFileSelection(e.target.files[0]);
  });

  document.getElementById('imageInput').addEventListener('change', (e) => {
    handleImageFileSelection(e.target.files[0]);
  });

  // Submit Review Form
  document.getElementById('reviewForm').addEventListener('submit', (e) => {
    e.preventDefault();
    const merchantName = document.getElementById('merchantInput').value.trim();
    const amount = parseFloat(document.getElementById('amountInput').value) || 0;
    const date = document.getElementById('dateInput').value || new Date().toISOString().split('T')[0];
    const category = document.getElementById('categorySelect').value;
    const note = document.getElementById('noteInput').value.trim();

    const txData = {
      merchantName,
      amount,
      date,
      category,
      note,
      imagePath: currentImageDataUrl
    };

    // 1. Save locally to LocalStorage immediately
    saveTransaction(txData);

    // 2. Reset current image selection
    currentImageDataUrl = null;

    // 3. Immediately update UI state & charts
    transactions = getStoredTransactions();
    renderCharts();
    renderTransactionsList();

    // 4. Close modal immediately and reset form
    modal.classList.remove('active');
    document.getElementById('reviewForm').reset();
    document.getElementById('reviewForm').style.display = 'none';

    // 5. Async background sync to Firebase Firestore (non-blocking)
    saveTransactionToFirebase(txData).then(() => {
      console.log('Synced receipt transaction to Firebase Firestore Cloud');
    }).catch((firebaseErr) => {
      console.warn('Firebase cloud sync fallback to local storage:', firebaseErr);
    });
  });
}

function runHeuristicOCR(rawLines) {
  const result = HeuristicReceiptParserJS.parse(rawLines);

  document.getElementById('merchantInput').value = result.merchantName;
  document.getElementById('amountInput').value = result.totalAmount;
  document.getElementById('dateInput').value = result.transactionDate;
  document.getElementById('categorySelect').value = result.category;

  const reviewForm = document.getElementById('reviewForm');
  reviewForm.style.display = 'block';
  document.getElementById('ocrLoading').style.display = 'none';

  // Smooth scroll form into view so submit button is easy to see
  setTimeout(() => {
    reviewForm.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  }, 100);
}
