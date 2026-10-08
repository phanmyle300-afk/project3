// Local Storage Database Service for Web Runner Demo

const STORAGE_KEY = 'receipt_tracker_transactions';

const SAMPLE_TRANSACTIONS = [
  {
    id: 1,
    merchantName: 'Siêu thị WinMart+',
    amount: 245000,
    date: new Date().toISOString().split('T')[0],
    category: 'Thực phẩm',
    note: 'Rau củ và sữa tươi Vinamilk',
    confidenceScore: 0.92
  },
  {
    id: 2,
    merchantName: 'Highlands Coffee',
    amount: 65000,
    date: new Date(Date.now() - 86400000).toISOString().split('T')[0],
    category: 'Thực phẩm',
    note: 'Cà phê phin sữa đá size L',
    confidenceScore: 0.88
  },
  {
    id: 3,
    merchantName: 'Nhà sách Fahasa',
    amount: 180000,
    date: new Date(Date.now() - 86400000 * 2).toISOString().split('T')[0],
    category: 'Học tập',
    note: 'Sách Flutter & Sổ tay Dart',
    confidenceScore: 0.95
  },
  {
    id: 4,
    merchantName: 'GrabBike',
    amount: 42000,
    date: new Date(Date.now() - 86400000 * 3).toISOString().split('T')[0],
    category: 'Du lịch & Di chuyển',
    note: 'Di chuyển đến thư viện trường',
    confidenceScore: 0.90
  },
  {
    id: 5,
    merchantName: 'CellphoneS',
    amount: 450000,
    date: new Date(Date.now() - 86400000 * 5).toISOString().split('T')[0],
    category: 'Thiết bị & Đồ dùng',
    note: 'Củ sạc Anker Fast Charge 30W',
    confidenceScore: 0.91
  },
  {
    id: 6,
    merchantName: 'Rạp CGV Cinemas',
    amount: 190000,
    date: new Date(Date.now() - 86400000 * 6).toISOString().split('T')[0],
    category: 'Giải trí',
    note: 'Vé xem phim cuối tuần',
    confidenceScore: 0.87
  }
];

export function getStoredTransactions() {
  if (typeof localStorage === 'undefined') return SAMPLE_TRANSACTIONS;
  const data = localStorage.getItem(STORAGE_KEY);
  if (!data) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(SAMPLE_TRANSACTIONS));
    return SAMPLE_TRANSACTIONS;
  }
  try {
    return JSON.parse(data);
  } catch (e) {
    return SAMPLE_TRANSACTIONS;
  }
}

export function saveTransaction(tx) {
  const list = getStoredTransactions();
  const newTx = {
    id: Date.now(),
    ...tx
  };
  list.unshift(newTx);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(list));
  return newTx;
}

export function deleteTransaction(id) {
  const list = getStoredTransactions().filter(t => t.id !== id);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(list));
}

// Monthly Budget Management
const BUDGET_KEY = 'receipt_tracker_budget';
export function getMonthlyBudget() {
  const val = localStorage.getItem(BUDGET_KEY);
  return val ? parseFloat(val) : 5000000;
}

export function setMonthlyBudget(amount) {
  localStorage.setItem(BUDGET_KEY, amount.toString());
}

// Backup Export / Import JSON
export function exportTransactionsJSON() {
  const txs = getStoredTransactions();
  const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(txs, null, 2));
  const downloadAnchor = document.createElement('a');
  downloadAnchor.setAttribute("href", dataStr);
  downloadAnchor.setAttribute("download", `expenses_backup_${Date.now()}.json`);
  document.body.appendChild(downloadAnchor);
  downloadAnchor.click();
  downloadAnchor.remove();
}

export function importTransactionsJSON(jsonString) {
  try {
    const list = JSON.parse(jsonString);
    if (Array.isArray(list)) {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(list));
      return true;
    }
  } catch (e) {
    console.error('Failed to import JSON', e);
  }
  return false;
}
