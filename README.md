# Hướng Dẫn Kết Nối & Lưu Dữ Liệu Hóa Đơn (Database Guide)

Dự án sử dụng mô hình **Offline-First Hybrid Database**: Lưu trữ tức thì vào cơ sở dữ liệu SQLite cục bộ trên thiết bị và tự động đồng bộ lên **Firebase Cloud Firestore & Storage** khi có kết nối Internet.

---

## 🗄️ 1. Cơ Sở Dữ Liệu Cục Bộ (Local SQLite Database)

Đã cài đặt sẵn trong [**`lib/services/database_helper.dart`**](file:///c:/Users/ACERPC/Documents/dnentang/project3/lib/services/database_helper.dart).

### Cách sử dụng trong code Dart/Flutter:

```dart
import 'services/database_helper.dart';
import 'models/transaction_model.dart';
import 'models/category.dart';

// 1. Lưu hóa đơn mới vào SQLite
final newTx = TransactionModel(
  merchantName: 'Siêu thị WinMart',
  amount: 245000,
  date: DateTime.now(),
  category: ExpenseCategory.food,
  note: 'Rau củ quả',
);
int id = await DatabaseHelper.instance.insertTransaction(newTx);

// 2. Lấy danh sách giao dịch
List<TransactionModel> list = await DatabaseHelper.instance.getAllTransactions();

// 3. Lấy tổng chi tiêu theo danh mục (cho Biểu đồ CustomPainter)
Map<ExpenseCategory, double> totals = await DatabaseHelper.instance.getCategoryTotals();

// 4. Xóa hóa đơn
await DatabaseHelper.instance.deleteTransaction(id);
```

---

## ☁️ 2. Kết Nối Cơ Sở Dữ Liệu Đám Mây (Firebase Firestore & Storage)

Đã tạo cấu hình và dịch vụ sẵn tại [**`lib/services/firebase_service.dart`**](file:///c:/Users/ACERPC/Documents/dnentang/project3/lib/services/firebase_service.dart).

### 🚀 3 Bước Kết Nối Firebase Cho Dự Án:

#### **Bước 1: Tạo dự án trên Firebase Console**
1. Truy cập [https://console.firebase.google.com/](https://console.firebase.google.com/).
2. Chọn **Add Project** -> Đặt tên dự án `SmartReceiptTracker`.
3. Bật **Cloud Firestore Database** (chọn mode `Start in test mode`).
4. Bật **Firebase Storage** (chọn lưu trữ hình ảnh hóa đơn).

#### **Bước 2: Cài đặt Firebase CLI & Đăng ký App Flutter**
Chạy câu lệnh sau trong terminal để tự động tạo file `firebase_options.dart`:
```bash
npm install -g firebase-tools
dart pub global activate flutterfire_cli
flutterfire configure
```

#### **Bước 3: Khởi tạo Firebase trong `lib/main.dart`**
Thêm lệnh khởi tạo vào hàm `main()`:
```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SmartReceiptApp());
}
```

---

## 📱 Hướng Dẫn Chạy & Chụp Ảnh Hóa Đơn Trực Tiếp Trên Điện Thoại

Ứng dụng hoàn toàn hỗ trợ chạy trên **điện thoại thật (Android & iOS)** và chụp ảnh hóa đơn bằng camera máy theo **2 cách**:

### Cách 1: Chạy Ứng Dụng Native Flutter (Khuyên dùng)
1. **Bật chế độ Gỡ lỗi USB (USB Debugging)** trên điện thoại Android hoặc iOS.
2. Kết nối điện thoại với máy tính qua dây cáp USB.
3. Trong Terminal của dự án, chạy lệnh:
   ```bash
   flutter run
   ```
4. **Trải nghiệm trên điện thoại**:
   - Nhấp nút **"QUÉT HÓA ĐƠN OCR"**.
   - Camera điện thoại sẽ mở trực tiếp với khung ngắm laser (`CameraOverlayPainter`), tính năng bật/tắt đèn flash và chạm để lấy nét.
   - Khi bấm chụp, Google ML Kit OCR trên điện thoại sẽ phân tích văn bản ngoại tuyến và trích xuất số tiền, nơi bán, ngày giao dịch tự động!

---

### Cách 2: Trải Nghiệm Qua Trình Duyệt Web Điện Thoại (Không cần cài APK)
1. Kết nối điện thoại và máy tính vào **cùng một mạng Wi-Fi**.
2. Trên máy tính, khởi chạy server web:
   ```bash
   npm run dev
   ```
3. Mở trình duyệt (Safari / Chrome) trên điện thoại và truy cập địa chỉ IP máy tính:
   👉 **`http://<Địa_Chỉ_IP_Máy_Tính>:3000/`** (Ví dụ: `http://10.60.26.60:3000/`)
4. Bấm nút **"📁 Chọn ảnh hóa đơn từ máy"** hoặc biểu tượng camera $\rightarrow$ Điện thoại sẽ tự động mở ống kính Camera thực tế để bạn chụp ảnh hóa đơn và phân tích ngay lập tức!
