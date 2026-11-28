# iDesk

**Chế độ máy tính cho iPhone và iPad.** Nối với màn hình, TV hoặc laptop: màn hình lớn có desktop với cửa sổ, thanh
tác vụ, trang web bản máy tính và app iOS chạy trong cửa sổ. iPhone thành trackpad và bàn phím.

[English](README.md) · Phát triển bởi **Kryvanta** · Dùng Android? Xem [Olyvexis](https://github.com/Kryvanta/Olyvexis), dự án chị em có cùng giao diện và phím tắt

> **Thử nghiệm.** iDesk dùng API riêng của UIKit, cài bằng cách sideload, và bản iOS sau có thể làm hỏng vài phần.

## Tính năng

- **Cửa sổ**: kéo, đổi cỡ, ghép bố cục (nửa, một phần ba, một phần tư), màn hình ảo, Spotlight (⌘ + Space), ⌥ + Tab.
- **Trình duyệt**: tab, trang bản máy tính, thanh dấu trang, chặn quảng cáo với danh sách riêng, chế độ đọc, dịch,
  trang tối.
- **App iOS từ file IPA** chạy trong cửa sổ, nhiều app cùng lúc. Cuộn hai ngón chuyển từng video trên TikTok, Reels,
  Shorts; chụm để thu phóng; *Tắt hẳn app* trong menu cửa sổ.
- **Tệp**: thư mục, tìm kiếm, zip, thùng rác, xem nhanh, trình soạn văn bản.
- **Desktop**: widget, ghi chú dán, hình nền, lịch sử clipboard (⌘ + Shift + V), chụp và ghi màn hình.
- **Nhập liệu**: cử chỉ trackpad, chụm để phóng to, gõ mọi ngôn ngữ (Telex, VNI…), gõ bằng giọng nói, bàn phím
  Bluetooth, chuột, tay cầm.
- **Cập nhật trong app**: *Cài đặt › Trợ giúp › Cập nhật* vẫn giữ các app iOS.
- **Gửi báo cáo** khi lỗi sẽ mở sẵn một issue trên GitHub.

## Nối màn hình

| Cách             | Cần gì                                                                 |
| ---------------- | ---------------------------------------------------------------------- |
| Cáp              | Cáp USB-C → HDMI, hoặc bộ chuyển Lightning → HDMI của Apple            |
| AirPlay          | Apple TV, TV có AirPlay hoặc máy Mac                                   |
| Laptop           | Bấm **Laptop** rồi mở địa chỉ trong trình duyệt của laptop (cùng Wi-Fi) |

Ở chế độ laptop, xoay ngang iPhone thì iPhone thành màn hình luôn.

## Cài đặt

Cần **iOS 17+**: iPhone XS / XR trở lên, hoặc iPad.

Tải `iDesk-<phiên bản>.ipa` ở [Releases](https://github.com/itshieuk/iDesk/releases), rồi ký và cài bằng ESign,
Feather hoặc Scarlet. Tự build (Xcode 15+ và [XcodeGen](https://github.com/yonaskolb/XcodeGen)):

```bash
brew install xcodegen
git clone https://github.com/itshieuk/iDesk.git && cd iDesk
xcodegen
scripts/build-ipa.sh      # → build/iDesk.ipa
```

## Sử dụng

| Trên iPhone            | Làm gì                           | Bàn phím (⌘) | Làm gì                     |
| ---------------------- | -------------------------------- | ------------ | -------------------------- |
| Một ngón               | Di chuyển con trỏ                | T / N / W    | Tab mới / cửa sổ mới, đóng |
| Chạm / chạm hai ngón   | Bấm / chuột phải                 | Shift + T    | Mở lại thứ vừa đóng        |
| Kéo hai ngón           | Cuộn                             | L / R        | Thanh địa chỉ / tải lại    |
| Chụm                   | Phóng to, thu nhỏ                | F            | Tìm trong trang            |
| Giữ rồi kéo            | Kéo hoặc đổi cỡ cửa sổ           | Space        | Spotlight                  |
| Ba ngón ↑ / ↓ / chạm   | App gần đây / Desktop / Quay lại | /            | Mọi phím tắt               |

## App iOS từ file IPA

1. Bấm **App** trên iPhone và thêm file `.ipa` đã giải mã.
2. Bấm **Cài app mới vào iDesk** rồi chọn ESign: ESign ký lại iDesk kèm các app bên trong.
3. Mở lại iDesk: các app nằm trong menu ứng dụng.

iOS chỉ chạy code nằm trong app đã cài, nên phải cài lại. App từ App Store không hiện được. Thông báo đẩy, iCloud và
chạy nền không có, và mọi app dùng chung bộ nhớ của iDesk.

**Lỗi đã biết:** YouTube có thể báo "Không có luồng"; Facebook có thể đòi captcha; vài IPA mod làm iOS đóng iDesk.

## Phát triển

- `-iDeskPreview` hiện desktop trên màn hình iPhone. `scripts/sim-ipa.sh App.ipa` chuyển IPA để chạy trên Simulator.
- Code: `App/` các scene, `Desktop/` desktop và trình duyệt, `Controller/` màn hình iPhone, `Input/` chuột, `Guest/`
  nạp app.
- Chuỗi chữ: `iDesk/Localizable.xcstrings`. Phát hành: đẩy tag như `v0.6.5`.

[GPL-3.0](LICENSE) · © Kryvanta · Chỉ nạp app bạn có quyền dùng. iDesk không liên quan tới Apple hay nhà phát triển app nào.
