// Heuristic Regex Engine for Parsing Vietnamese Receipts (JavaScript Mirror of Dart Implementation)

export class HeuristicReceiptParserJS {
  static parse(rawLines) {
    if (!rawLines || rawLines.length === 0) {
      return {
        merchantName: 'Cửa hàng không xác định',
        totalAmount: 0,
        transactionDate: new Date().toISOString().split('T')[0],
        category: ' Khác',
        confidenceScore: 0.0,
        rawLines: []
      };
    }

    const cleanedLines = rawLines.map(l => l.trim()).filter(l => l.length > 0);
    const merchantName = this._extractMerchant(cleanedLines);
    const totalAmount = this._extractTotalAmount(cleanedLines);
    const transactionDate = this._extractDate(cleanedLines);
    const category = this._determineCategory(merchantName, cleanedLines);
    const confidenceScore = this._calculateConfidence(merchantName, totalAmount, transactionDate);

    return {
      merchantName,
      totalAmount,
      transactionDate,
      category,
      confidenceScore,
      rawLines: cleanedLines
    };
  }

  static _extractMerchant(lines) {
    const ignoreKeywords = [
      'HOA DON', 'HÓA ĐƠN', 'PHIẾU THANH TOÁN', 'RECEIPT', 'VAT',
      'CỬA HÀNG', 'THU NGÂN', 'TEL', 'HOTLINE', 'MST', 'MÃ SỐ THUẾ',
      'WELCOME', 'XIN CẢM ƠN', 'THANK YOU', 'NGÀY', 'DATE', 'ADDRESS'
    ];

    const knownMerchants = [
      /WINMART\+?/i,
      /CO\.?OP\s?MART/i,
      /CIRCLE\s?K/i,
      /HIGHLANDS\s?COFFEE/i,
      /PHÚC\s?LONG|PHUC\s?LONG/i,
      /BÁCH\s?HÓA\s?XANH|BACH\s?HOA\s?XANH/i,
      /MINISTOP/i,
      /GS25/i,
      /STARBUCKS/i,
      /FAHASA/i,
      /CELLPHONES|CELLPHONE\s?S/i,
      /THẾ\s?GIỚI\s?DI\s?ĐỘNG/i,
      /GRAB|BE|GOJEK/i,
      /SHOPEE|TIKI|LAZADA/i,
      /CGV|LOTTE\s?CINEMA|BHD/i
    ];

    for (let i = 0; i < Math.min(lines.length, 6); i++) {
      for (const pattern of knownMerchants) {
        if (pattern.test(lines[i])) {
          return lines[i].trim();
        }
      }
    }

    for (let i = 0; i < Math.min(lines.length, 4); i++) {
      const upper = lines[i].toUpperCase();
      let ignore = false;
      for (const kw of ignoreKeywords) {
        if (upper.includes(kw)) {
          ignore = true;
          break;
        }
      }
      if (!ignore && lines[i].length >= 3 && !/^\d+$/.test(lines[i])) {
        return lines[i].trim();
      }
    }

    return 'Siêu thị / Cửa hàng tiện lợi';
  }

  static _extractTotalAmount(lines) {
    const grandTotalKeywords = [
      'TỔNG CỘNG', 'TONG CONG', 'THÀNH TIỀN', 'THANH TIEN', 'TỔNG TIỀN',
      'CẦN THANH TOÁN', 'TOTAL', 'SUM', 'GIÁ TRỊ', 'CỘNG TIỀN'
    ];
    const tenderKeywords = ['TIỀN MẶT', 'CASH', 'PAYMENT'];

    // 1. Check grand total keywords first
    for (let i = lines.length - 1; i >= 0; i--) {
      const upper = lines[i].toUpperCase();
      for (const kw of grandTotalKeywords) {
        if (upper.includes(kw)) {
          const val = this._parseAmountFromText(lines[i]);
          if (val > 0) return val;
          if (i + 1 < lines.length) {
            const nextVal = this._parseAmountFromText(lines[i + 1]);
            if (nextVal > 0) return nextVal;
          }
        }
      }
    }

    // 2. Check tender keywords
    for (let i = lines.length - 1; i >= 0; i--) {
      const upper = lines[i].toUpperCase();
      for (const kw of tenderKeywords) {
        if (upper.includes(kw)) {
          const val = this._parseAmountFromText(lines[i]);
          if (val > 0) return val;
        }
      }
    }

    let maxAmount = 0;
    for (let i = lines.length - 1; i >= 0; i--) {
      const val = this._parseAmountFromText(lines[i]);
      if (val > maxAmount && val < 50000000 && !this._isPhoneOrTax(lines[i])) {
        maxAmount = val;
      }
    }

    return maxAmount;
  }

  static _parseAmountFromText(text) {
    const regex = /(\d{1,3}(?:[.,\s]\d{3})*(?:[.,]\d{2})?|\d+)\s*(?:VND|VNĐ|đ|D)?/gi;
    let match;
    let maxFound = 0;

    while ((match = regex.exec(text)) !== null) {
      let raw = match[1];
      if (/^\d{1,3}(\.\d{3})+$/.test(raw)) {
        raw = raw.replace(/\./g, '');
      } else if (/^\d{1,3}(,\d{3})+$/.test(raw)) {
        raw = raw.replace(/,/g, '');
      } else if (raw.includes(',')) {
        raw = raw.replace(/,/g, '');
      } else {
        raw = raw.replace(/[^\d.]/g, '');
      }

      const num = parseFloat(raw);
      if (num >= 1000 && num > maxFound) {
        maxFound = num;
      }
    }
    return maxFound;
  }

  static _isPhoneOrTax(line) {
    const lower = line.toLowerCase();
    if (lower.includes('mst') || lower.includes('tel') || lower.includes('hotline')) return true;
    if (/\b(0\d{9,10})\b/.test(line)) return true;
    return false;
  }

  static _extractDate(lines) {
    const dateRegexes = [
      /\b(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})\b/,
      /\b(\d{4})[/.-](\d{1,2})[/.-](\d{1,2})\b/,
      /\b(\d{1,2})[/.-](\d{1,2})[/.-](\d{2})\b/
    ];

    for (const line of lines) {
      for (const regex of dateRegexes) {
        const m = line.match(regex);
        if (m) {
          try {
            let y, mth, d;
            if (m[1].length === 4) {
              y = parseInt(m[1]);
              mth = parseInt(m[2]);
              d = parseInt(m[3]);
            } else {
              d = parseInt(m[1]);
              mth = parseInt(m[2]);
              y = m[3].length === 2 ? 2000 + parseInt(m[3]) : parseInt(m[3]);
            }
            if (mth >= 1 && mth <= 12 && d >= 1 && d <= 31) {
              return `${y}-${String(mth).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
            }
          } catch (e) {}
        }
      }
    }
    return new Date().toISOString().split('T')[0];
  }

  static _determineCategory(merchant, lines) {
    const fullText = ([merchant, ...lines]).join(' ').toLowerCase();

    if (fullText.includes('winmart') || fullText.includes('coopmart') || fullText.includes('circle k') || fullText.includes('highlands') || fullText.includes('cà phê') || fullText.includes('bách hóa') || fullText.includes('phúc long')) {
      return 'Thực phẩm';
    }
    if (fullText.includes('fahasa') || fullText.includes('sách') || fullText.includes('bút') || fullText.includes('học phí')) {
      return 'Học tập';
    }
    if (fullText.includes('grab') || fullText.includes('be') || fullText.includes('gojek') || fullText.includes('xăng') || fullText.includes('taxi')) {
      return 'Du lịch & Di chuyển';
    }
    if (fullText.includes('cellphones') || fullText.includes('thế giới di động') || fullText.includes('laptop') || fullText.includes('sạc')) {
      return 'Thiết bị & Đồ dùng';
    }
    if (fullText.includes('cgv') || fullText.includes('lotte') || fullText.includes('phim') || fullText.includes('game')) {
      return 'Giải trí';
    }

    return 'Khác';
  }

  static _calculateConfidence(merchant, amount, date) {
    let score = 0.4;
    if (merchant !== 'Siêu thị / Cửa hàng tiện lợi') score += 0.25;
    if (amount > 0) score += 0.25;
    if (date) score += 0.1;
    return Math.min(score, 1.0);
  }
}
