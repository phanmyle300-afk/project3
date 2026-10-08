// HTML5 Canvas Chart Renderer mirroring Flutter CustomPainter logic

export const CATEGORY_COLORS = {
  'Thực phẩm': '#FF5252',
  'Học tập': '#448AFF',
  'Du lịch & Di chuyển': '#FFB300',
  'Thiết bị & Đồ dùng': '#7C4DFF',
  'Giải trí': '#00E676',
  'Khác': '#78909C'
};

export function renderDonutChart(canvas, categoryTotals, selectedCategory = null, onSelect = null) {
  const ctx = canvas.getContext('2d');
  const dpr = window.devicePixelRatio || 1;
  const width = canvas.parentElement.clientWidth;
  const height = 260;

  canvas.width = width * dpr;
  canvas.height = height * dpr;
  canvas.style.width = `${width}px`;
  canvas.style.height = `${height}px`;

  ctx.scale(dpr, dpr);
  ctx.clearRect(0, 0, width, height);

  const total = Object.values(categoryTotals).reduce((sum, val) => sum + val, 0);
  const centerX = width / 2;
  const centerY = height / 2;
  const outerRadius = Math.min(width, height) / 2 - 20;
  const strokeWidth = 32;

  if (total <= 0) {
    ctx.beginPath();
    ctx.arc(centerX, centerY, outerRadius, 0, 2 * Math.PI);
    ctx.lineWidth = strokeWidth;
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.08)';
    ctx.stroke();
    return;
  }

  let startAngle = -Math.PI / 2;
  const slices = [];

  for (const [cat, val] of Object.entries(categoryTotals)) {
    if (val <= 0) continue;

    const sweepAngle = (val / total) * 2 * Math.PI;
    const endAngle = startAngle + sweepAngle;
    const isSelected = (selectedCategory === cat);

    ctx.save();
    ctx.beginPath();
    ctx.arc(centerX, centerY, outerRadius, startAngle, endAngle);
    ctx.lineWidth = isSelected ? strokeWidth + 8 : strokeWidth;
    ctx.strokeStyle = CATEGORY_COLORS[cat] || '#78909C';
    ctx.lineCap = 'butt';

    if (isSelected) {
      ctx.shadowColor = CATEGORY_COLORS[cat];
      ctx.shadowBlur = 12;
    }

    ctx.stroke();
    ctx.restore();

    // Store slice geometry for click hit testing
    slices.push({ cat, startAngle, endAngle });

    startAngle = endAngle;
  }

  // Draw Center Text
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';

  ctx.font = '500 12px Inter, sans-serif';
  ctx.fillStyle = '#94A3B8';
  ctx.fillText(selectedCategory ? selectedCategory : 'Tổng Chi Tiêu', centerX, centerY - 12);

  ctx.font = '700 18px Inter, sans-serif';
  ctx.fillStyle = selectedCategory ? (CATEGORY_COLORS[selectedCategory] || '#FFF') : '#FFFFFF';
  const displayVal = selectedCategory ? (categoryTotals[selectedCategory] || 0) : total;
  ctx.fillText(`${displayVal.toLocaleString('vi-VN')} đ`, centerX, centerY + 12);

  // Setup click event for canvas selection
  if (onSelect && !canvas._hasClickListener) {
    canvas._hasClickListener = true;
    canvas.addEventListener('click', (e) => {
      const rect = canvas.getBoundingClientRect();
      const x = e.clientX - rect.left - centerX;
      const y = e.clientY - rect.top - centerY;
      const dist = Math.sqrt(x * x + y * y);
      const innerRadius = outerRadius - strokeWidth / 2;
      const outerBound = outerRadius + strokeWidth / 2;

      if (dist >= innerRadius && dist <= outerBound) {
        let angle = Math.atan2(y, x);
        if (angle < -Math.PI / 2) angle += 2 * Math.PI;
        angle += Math.PI / 2;

        let found = null;
        let cur = 0;
        for (const [cat, val] of Object.entries(categoryTotals)) {
          if (val <= 0) continue;
          const sweep = (val / total) * 2 * Math.PI;
          if (angle >= cur && angle <= cur + sweep) {
            found = cat;
            break;
          }
          cur += sweep;
        }
        onSelect(found);
      } else {
        onSelect(null);
      }
    });
  }
}

export function renderWeeklyBarChart(canvas, weeklyData, selectedIndex = null, onSelect = null) {
  const ctx = canvas.getContext('2d');
  const dpr = window.devicePixelRatio || 1;
  const width = canvas.parentElement.clientWidth;
  const height = 220;

  canvas.width = width * dpr;
  canvas.height = height * dpr;
  canvas.style.width = `${width}px`;
  canvas.style.height = `${height}px`;

  ctx.scale(dpr, dpr);
  ctx.clearRect(0, 0, width, height);

  const leftMargin = 36;
  const rightMargin = 16;
  const topMargin = 30;
  const bottomMargin = 30;

  const chartWidth = width - leftMargin - rightMargin;
  const chartHeight = height - topMargin - bottomMargin;

  let maxVal = Math.max(...weeklyData.map(d => d.amount), 100000);

  // Draw Horizontal Grid Lines & Y Labels
  ctx.lineWidth = 1;
  ctx.strokeStyle = 'rgba(255, 255, 255, 0.08)';
  ctx.fillStyle = '#64748B';
  ctx.font = '500 10px Inter, sans-serif';
  ctx.textAlign = 'right';

  for (let i = 0; i <= 3; i++) {
    const ratio = i / 3;
    const y = topMargin + chartHeight * (1 - ratio);

    ctx.beginPath();
    ctx.moveTo(leftMargin, y);
    ctx.lineTo(width - rightMargin, y);
    ctx.stroke();

    const val = maxVal * ratio;
    const label = val >= 1000000 ? `${(val / 1000000).toFixed(1)}M` : (val >= 1000 ? `${(val / 1000).toFixed(0)}K` : '0');
    ctx.fillText(label, leftMargin - 6, y + 3);
  }

  // Draw Bars & X Labels
  const barGap = chartWidth / weeklyData.length;
  const barWidth = Math.min(barGap * 0.45, 24);

  weeklyData.forEach((item, i) => {
    const centerX = leftMargin + (i + 0.5) * barGap;
    const barH = (item.amount / maxVal) * chartHeight;
    const topY = topMargin + chartHeight - barH;
    const isSelected = (selectedIndex === i);

    // Gradient Bar
    const gradient = ctx.createLinearGradient(0, topY, 0, topMargin + chartHeight);
    if (isSelected) {
      gradient.addColorStop(0, '#FF5252');
      gradient.addColorStop(1, '#FF7A00');
    } else {
      gradient.addColorStop(0, '#6C5CE7');
      gradient.addColorStop(1, '#00CEC9');
    }

    ctx.save();
    ctx.fillStyle = gradient;
    if (isSelected) {
      ctx.shadowColor = '#FF5252';
      ctx.shadowBlur = 8;
    }

    // Rounded top rect
    const rx = centerX - barWidth / 2;
    const ry = topY;
    const rw = barWidth;
    const rh = Math.max(barH, 4);

    ctx.beginPath();
    ctx.roundRect(rx, ry, rw, rh, [6, 6, 0, 0]);
    ctx.fill();
    ctx.restore();

    // X Day Label
    ctx.textAlign = 'center';
    ctx.font = isSelected ? '700 11px Inter, sans-serif' : '400 11px Inter, sans-serif';
    ctx.fillStyle = isSelected ? '#FF5252' : '#94A3B8';
    ctx.fillText(item.dayLabel, centerX, height - bottomMargin + 16);

    // Tooltip
    if (isSelected) {
      ctx.fillStyle = '#FF5252';
      const text = `${Math.round(item.amount).toLocaleString('vi-VN')}đ`;
      ctx.font = '700 10px Inter, sans-serif';
      const tw = ctx.measureText(text).width + 12;
      const bwY = Math.max(topY - 18, 12);
      ctx.beginPath();
      ctx.roundRect(centerX - tw / 2, bwY - 10, tw, 18, 4);
      ctx.fill();

      ctx.fillStyle = '#FFFFFF';
      ctx.fillText(text, centerX, bwY + 2);
    }
  });

  if (onSelect && !canvas._hasBarListener) {
    canvas._hasBarListener = true;
    canvas.addEventListener('click', (e) => {
      const rect = canvas.getBoundingClientRect();
      const clickX = e.clientX - rect.left;
      const idx = Math.floor((clickX - leftMargin) / barGap);
      if (idx >= 0 && idx < weeklyData.length) {
        onSelect(idx);
      } else {
        onSelect(null);
      }
    });
  }
}
