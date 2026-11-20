# iDesk

**Chế độ máy tính cho iPhone.** Cắm iPhone vào màn hình hoặc TV: màn hình lớn có desktop với cửa sổ, thanh tác vụ,
menu ứng dụng, trang web bản máy tính và app iOS chạy trong cửa sổ. iPhone thành trackpad và bàn phím.

[English](README.md)

> **Thử nghiệm.** iDesk dùng API riêng của UIKit, cài bằng cách sideload, và bản iOS sau có thể làm hỏng vài phần.

## Tính năng

- **Cửa sổ** kéo, đổi cỡ, ghép nửa màn hình (kéo ra mép hoặc ⌘ + mũi tên), thu nhỏ, phóng to; thanh tác vụ có
  App gần đây, Màn hình chính và Quay lại; menu ứng dụng có tìm kiếm và hàng Gần đây; ⌥ + Tab; nhiều màn hình ảo (tùy
  chọn). Cửa sổ đang mở được mở lại ở lần sau.
- **Trình duyệt** có tab, trang bản máy tính, cửa sổ đăng nhập, video toàn màn hình, tìm trong trang, phóng to, dấu
  trang và lịch sử, chặn quảng cáo và theo dõi, chỉnh cỡ chữ cho mọi trang.
- **Tệp**: file tải về và ảnh chụp màn hình, thư mục, đổi tên, chuyển chỗ, tìm, sắp xếp, tạo file chữ, giải nén zip,
  nhập từ iPhone, xem nhanh (Space). File chữ mở trong trình soạn tự lưu, có tìm và thay thế, Lưu thành.
- **App iOS từ file IPA đã giải mã**, chạy trong cửa sổ, nhiều app cùng lúc.
- **iPhone làm thiết bị nhập**: cử chỉ trackpad, gõ mọi ngôn ngữ (Telex, VNI…), bàn phím Bluetooth, chuột qua
  AssistiveTouch, và nút dán thứ bạn đã sao chép trên iPhone (ví dụ mật khẩu).
- **Desktop**: biểu tượng tự sắp và chỉnh cỡ, file trên desktop, hình nền, bảng nhanh và thông báo, pin, nhiệt độ và
  bộ nhớ trên khay, độ phân giải màn hình và viền TV.
- Hướng dẫn lần đầu, báo lỗi khi thoát hoặc treo kèm nút **Sao chép lỗi**, tiếng Anh và tiếng Việt.

## Cài đặt

Cần iPhone **iOS 17+** và cáp USB-C → HDMI/DisplayPort (hoặc bộ chuyển Lightning AV của Apple).

Tải `iDesk-<phiên bản>.ipa` ở [Releases](https://github.com/itshieuk/iDesk/releases), rồi ký và cài bằng ESign,
Feather hoặc Scarlet. Tự build (Xcode 15+ và [XcodeGen](https://github.com/yonaskolb/XcodeGen)):

```bash
brew install xcodegen
git clone https://github.com/itshieuk/iDesk.git && cd iDesk
xcodegen
scripts/build-ipa.sh      # → build/iDesk.ipa (hoặc mở iDesk.xcodeproj và bấm Run)
```

## Sử dụng

Mở iDesk, rồi cắm màn hình.

| Trên iPhone            | Làm gì                      | Bàn phím (⌘ hoặc Ctrl) | Làm gì                        |
| ---------------------- | --------------------------- | ---------------------- | ----------------------------- |
| Một ngón               | Di chuyển con trỏ           | T / N / W              | Tab mới / cửa sổ mới, đóng    |
| Chạm / chạm hai ngón   | Bấm / chuột phải            | Shift + T              | Mở lại thứ vừa đóng           |
| Kéo hai ngón           | Cuộn                        | L / R                  | Thanh địa chỉ / tải lại       |
| Giữ rồi kéo            | Kéo hoặc đổi cỡ cửa sổ      | F / G                  | Tìm / chỗ tiếp theo           |
| Ba ngón ↑ / ↓ / chạm   | App gần đây / Desktop / Quay lại | = / − / 0         | Phóng to, thu nhỏ             |
| Chạm bốn ngón          | Menu ứng dụng               | Chỉ ⌘ / Tab            | Menu ứng dụng, App gần đây    |
| Xoay ngang iPhone      | Cả màn hình thành trackpad  | /                      | Mọi phím tắt                  |

Bàn phím không có ⌘ thì phím logo làm việc tương tự. Chuột chạy qua *Cài đặt → Trợ năng → Cảm ứng → AssistiveTouch*: khi đó iPhone hiện
bản sao desktop để trỏ vào (**Kiểm tra chuột** cho biết iDesk nhận được gì). Cài đặt nằm trên desktop; khi chưa cắm
màn hình, nút bánh răng trên iPhone chỉ còn phần trackpad và chuột.

## App iOS từ file IPA

1. Bấm **App** (nút hình hộp) trên iPhone và thêm file `.ipa` đã giải mã.
2. Bấm **Cài app mới vào iDesk** rồi chọn ESign: ESign ký lại iDesk kèm các app bên trong và cài đặt.
3. Mở lại iDesk: các app nằm trong menu ứng dụng.

iOS chỉ chạy code nằm trong một app đã cài, nên phải cài lại (với chứng chỉ phát triển, mục **Nâng cao** ký app ngay
trên iPhone). App cài từ App Store không hiện được: iOS giữ mỗi app trong hộp cát riêng.

Phần lớn app chạy được: màn hình, chạm, gõ, mạng, đăng nhập, dữ liệu đã lưu. Không có: thông báo đẩy, iCloud, chạy
nền và tiện ích mở rộng. App kiểm tra bị sửa đổi có thể tự thoát, và mọi app dùng chung bộ nhớ của iDesk. Nếu một app
làm iDesk thoát, lần mở sau sẽ hiện **Sao chép lỗi**: hãy gửi nội dung đó.

## Phát triển

- `-iDeskPreview` hiện desktop trên màn hình iPhone (chạm trực tiếp; giữ để chuột phải). Thêm `-iDeskInstall <ipa…>`
  hoặc `-iDeskOpen <url>`. `scripts/sim-ipa.sh App.ipa` chuyển IPA để chạy trên Simulator.
- Code: `App/` các scene, `Desktop/` desktop và trình duyệt, `Controller/` màn hình iPhone, `Input/` chuột, `Guest/`
  nạp app (sửa Mach-O, vòng đời, shim cho bundle, keychain và hook dùng chung, chạm giả, báo lỗi).
- Chuỗi chữ: `iDesk/Localizable.xcstrings`. Phát hành: đẩy tag như `v0.5.2`.

**Lỗi đã biết:** trang web nhận sự kiện chuột qua JavaScript nên CSS `:hover` không có tác dụng và vài trang canvas
bỏ qua cú bấm. Khi chưa cắm màn hình, chỉ quản lý app được.

[MIT](LICENSE) · Chỉ nạp app bạn có quyền dùng. iDesk không liên quan tới Apple hay nhà phát triển app nào.
