# iDesk

**Chế độ desktop cho iPhone.** Cắm iPhone vào màn hình hoặc TV là có một desktop thật trên màn hình lớn: cửa sổ
kéo và đổi cỡ được, thanh tác vụ, menu Start, web bản máy tính, và cả app iOS khác chạy trong cửa sổ. iPhone trở
thành trackpad và bàn phím.

[English](README.md)

> **Tình trạng: thử nghiệm.** iDesk dùng API riêng của UIKit, dành cho cài ngoài (sideload) chứ không lên App
> Store, và bản iOS sau có thể làm hỏng một số phần.

## Tính năng

- **Desktop trên màn hình ngoài, theo kiểu Samsung DeX.** Cửa sổ kéo, đổi cỡ, phóng to, thu nhỏ, ghim nửa hoặc 1/4
  màn hình được (kéo ra mép hoặc góc, hoặc Win + mũi tên). Thanh tác vụ có app ghim (chấm nhỏ báo app đang mở), các
  cửa sổ đang mở, đồng hồ và pin. Menu Start có ô tìm kiếm, Alt+Tab hiện bảng chuyển cửa sổ, menu chuột phải ghim
  app và đổi cửa sổ app sang cỡ điện thoại, máy tính bảng hoặc nằm ngang. Cửa sổ đang mở được mở lại ở lần chạy sau.
- **Web bản máy tính.** Mỗi cửa sổ là một trình duyệt xin trang bản máy tính. Nhấp, cuộn và gõ chữ đều đi vào trang.
  Video toàn màn hình (YouTube, trình phát nhúng) phủ kín màn hình lớn.
- **App iOS trong cửa sổ.** Thêm file IPA đã giải mã là app chạy ngay trong iDesk thành cửa sổ, nhấp, kéo, cuộn và
  gõ được, chạy nhiều app cùng lúc.
- **iPhone làm thiết bị nhập.** Cử chỉ trackpad, trackpad kín màn hình khi xoay ngang, ô soạn chữ nhận mọi bàn phím
  và bộ gõ, gõ trực tiếp, bàn phím Bluetooth với phím tắt kiểu máy tính, chuột qua AssistiveTouch.
- **Cài đặt.** Độ sáng iPhone, độ sáng màn hình ngoài, hình nền (dải màu có sẵn hoặc ảnh của bạn), tốc độ di chuột
  và cuộn. Âm thanh phát qua màn hình: chỉnh âm lượng trên màn hình hoặc TV (qua HDMI và DisplayPort, iOS xuất âm
  thanh ở mức tối đa nên thanh âm lượng trên iPhone hay trong app đều không có tác dụng).
- **Tiếng Anh và tiếng Việt.** App theo ngôn ngữ của iPhone, ngôn ngữ khác thì hiện tiếng Anh.
- **Báo lỗi.** App nào làm iDesk thoát thì lần mở sau iDesk báo nguyên nhân, kèm nút **Sao chép lỗi**.

## Yêu cầu

- iPhone chạy **iOS 17 trở lên**.
- Cáp hoặc bộ chuyển ra màn hình: USB-C sang HDMI/DisplayPort (iPhone 15 trở lên), hoặc Lightning Digital AV
  Adapter của Apple (iPhone đời cũ).
- Để build: máy Mac có **Xcode 15+** và [XcodeGen](https://github.com/yonaskolb/XcodeGen).

## Cài đặt

**Bản dựng sẵn:** tải `iDesk-<phiên bản>.ipa` ở mục [Releases](https://github.com/itshieuk/iDesk/releases), mở bằng app
ký (ESign, Feather, Scarlet…), ký rồi cài.

**Tự build từ mã nguồn:**

```bash
brew install xcodegen
git clone https://github.com/itshieuk/iDesk.git
cd iDesk
xcodegen
```

Sau đó chọn một cách:

- **Xcode:** mở `iDesk.xcodeproj`, chọn Team ở *Signing & Capabilities* rồi bấm Run.
- **App ký** (ESign, Feather, Scarlet…): build file IPA chưa ký, rồi ký và cài bằng app đó.

  ```bash
  scripts/build-ipa.sh
  ```

  File nằm ở `build/iDesk.ipa`.

## Cách dùng

Mở iDesk rồi cắm màn hình. Màn hình lớn hiện desktop, iPhone hiện phần điều khiển.

### Trackpad

| Trên iPhone              | Tác dụng                                                              |
| ------------------------ | --------------------------------------------------------------------- |
| Kéo 1 ngón               | Di chuột                                                              |
| Chạm / chạm 2 lần        | Nhấp / nhấp đúp                                                       |
| Chạm 2 ngón              | Chuột phải                                                            |
| Kéo 2 ngón               | Cuộn                                                                  |
| Giữ khoảng 0,35 giây rồi kéo | Nhấn giữ và kéo: kéo thanh tiêu đề để di chuyển cửa sổ, kéo cạnh để đổi cỡ |

Xoay ngang iPhone thì cả màn hình là trackpad.

### Phần điều khiển trên iPhone

- **Thanh địa chỉ:** mở địa chỉ web hoặc tìm kiếm trong cửa sổ đang chọn.
- **Thanh công cụ:** lùi, tiến, tải lại, menu Start, cửa sổ mới, app từ IPA, đóng cửa sổ, gõ trực tiếp.
- **Ô soạn chữ:** gõ bằng bàn phím bất kỳ (Telex, VNI, tiếng Nhật, tiếng Trung…) rồi gửi vào ô đang chọn trên trang.
- **Nút bánh răng:** cài đặt. **Nút ở góc:** chế độ chuột (xem dưới).

### Bàn phím

Bàn phím Bluetooth gõ thẳng vào trang. Phím tắt dùng ⌘ hoặc Ctrl (bàn phím Windows thì phím Win là ⌘):

| Phím             | Tác dụng      | Phím  | Tác dụng                          |
| ---------------- | ------------- | ----- | --------------------------------- |
| T hoặc N         | Cửa sổ mới    | A     | Chọn hết                          |
| W                | Đóng cửa sổ   | C / V | Chép / dán                        |
| R                | Tải lại       | D     | Hiện màn hình nền                 |
| [ / ]            | Lùi / tiến    | M     | Thu nhỏ                           |
| Tab (hoặc Alt+Tab) | Bảng chuyển cửa sổ, nhả phím để chuyển | Esc | Đóng menu, thoát toàn màn hình |

Giống Windows và Samsung DeX:

| Phím               | Tác dụng                                                               |
| ------------------ | ---------------------------------------------------------------------- |
| Win (bấm riêng)    | Mở / đóng menu Start; gõ để tìm, Enter mở app đầu tiên                  |
| Win + ← / →        | Ghim cửa sổ vào nửa trái / phải                                         |
| Win + ↑ / ↓        | Đang ở một nửa: ghim 1/4 trên / dưới. Nếu không: ↑ phóng to, ↓ khôi phục rồi thu nhỏ |
| Alt + ← / → hoặc Ctrl + ← / → | Lùi / tiến                                                   |

### Chuột

Trên iPhone, iOS không cho app API con trỏ như trên iPad. Chuột chỉ chạy qua AssistiveTouch: *Cài đặt → Trợ năng →
Cảm ứng → AssistiveTouch*, rồi ghép chuột ở mục *Thiết bị trỏ*. iOS chỉ vẽ con trỏ đó trên màn hình iPhone và không
cho app biết nó ở đâu cho tới khi bấm.

Vì vậy khi AssistiveTouch bật, trackpad trên iPhone hiện **bản sao trực tiếp của desktop**. Trỏ vào đâu trên đó rồi
bấm thì con trỏ desktop tới đúng chỗ đó. Giữ để kéo, nút phải để mở menu, cuộn bằng 2 ngón hoặc con lăn. Nút ở góc
bật **chế độ chuột**: xoay ngang, bản sao desktop phủ kín màn hình.

### Ngôn ngữ

iDesk theo ngôn ngữ của iPhone. Muốn đổi riêng cho iDesk: *Cài đặt → iDesk → Ngôn ngữ*.

## Chạy app iOS từ file IPA

iDesk nạp app khác **vào ngay tiến trình của mình** và hiện cửa sổ của app đó trên desktop.

1. Trên iPhone bấm nút hình hộp → **Thêm IPA**, chọn một hoặc nhiều file `.ipa` đã giải mã.
2. iDesk lần lượt chuẩn bị từng app rồi tạo `iDesk-with-apps.ipa`, tức iDesk có kèm các app mới bên trong, và mở
   bảng chia sẻ.
3. Mở file đó bằng app ký, ký và cài đè lên iDesk như bình thường.
4. Mở lại iDesk và cắm màn hình: app có trên desktop và trong menu Start.

**Vì sao phải cài lại iDesk?** Với chứng chỉ thông thường, iOS chỉ cho chạy mã nằm sẵn trong app đã cài. Mã nằm
trong thư mục dữ liệu của app bị chặn, kể cả khi chữ ký hợp lệ. Nếu iDesk được cài bằng chứng chỉ phát triển
(`get-task-allow`, ví dụ qua SideStore hoặc AltStore), mục **Nâng cao: tự ký trên máy** ký app ngay trên iPhone và mở
được luôn.

**Dung lượng.** App nằm bên trong iDesk nên iDesk nặng xấp xỉ tổng các app. Muốn bỏ app: vuốt app → **Gỡ khỏi
iDesk**, rồi cài lại iDesk.

**Chạy được gì, không chạy được gì.** Phần lớn app mở và dùng được, nhưng không phải tất cả, vì app nằm trong app
khác không giống một lần mở bình thường.

- Chạy được: các màn hình của app, chạm, kéo, cuộn, gõ chữ, font riêng của app, mạng, đăng nhập, dữ liệu app lưu.
- Không chạy: thông báo đẩy, đồng bộ iCloud, tác vụ nền, widget và các phần mở rộng khác.
- App xoay ngang để xem toàn màn hình (trình phát video) thì cửa sổ phủ kín màn hình ngoài; app quay về dọc thì
  thu lại, hoặc bấm Esc.
- IPA gắn tweak có kèm thư viện jailbreak cũ (libsubstrate dùng libstdc++ đã bị iOS bỏ) vẫn nạp được: phần iOS
  không còn thì bỏ qua. Tweak sửa mã máy trong bộ nhớ thì vẫn không chạy được nếu không jailbreak.
- Màn hình hệ thống app mở ra (trang App Store, gửi mail, chia sẻ, chọn ảnh hoặc tệp) hiện trên màn hình iPhone để
  bạn thao tác bằng tay. Trình duyệt trong app mở thành cửa sổ web trên desktop.
- Đóng cửa sổ app là đưa app xuống nền (app tạm dừng, như khi thoát app trên iPhone). App chỉ tắt hẳn khi tắt
  iDesk: iOS không cho gỡ mã của app khỏi một tiến trình đang chạy.
- Dữ liệu app dùng chung với app "anh em" (keychain dùng chung, App Group) chỉ nằm trong iDesk.
- App tự kiểm tra môi trường (jailbreak, bị sửa, chữ ký) có thể không chạy hoặc tự tắt.
- Chạy được nhiều app cùng lúc nhưng chúng dùng chung RAM của iDesk: mở quá nhiều app nặng thì iOS tắt iDesk. Đóng
  cửa sổ chỉ ẩn app; app vẫn chạy cho tới khi tắt iDesk. Một app treo thì iDesk và các app khác treo theo.
- Hai app dùng cùng tên lớp Objective-C trong storyboard có thể ảnh hưởng nhau.

App làm iDesk thoát thì mở lại iDesk, bấm **Sao chép lỗi** và gửi kèm nội dung đó khi báo lỗi.

## Cách hoạt động

**Desktop.** Màn hình ngoài có scene riêng, vẽ toàn bộ desktop bằng SwiftUI. Scene đó không nhận chạm, nên iDesk tự
vẽ con trỏ và tự xác định con trỏ đang ở trên thứ gì. Cửa sổ web là WKWebView: nhấp, rê chuột, cuộn và phím được đưa
vào trang bằng JavaScript, và một đoạn script giả lập Fullscreen API mà WebKit trên iPhone không có.

**App từ file IPA** (`iDesk/Guest/`):

- `MachOPatcher` biến file thực thi của app thành thư viện mà `dlopen` chấp nhận (MH_DYLIB, `__PAGEZERO` nhỏ, tên
  thư viện, đổi `@executable_path`) và chỉ giữ mã arm64.
- `ImportWeakener` đánh dấu hàm hệ thống mà iOS này đã bỏ là "không bắt buộc", để thư viện cũ đi kèm (libsubstrate
  trong IPA gắn tweak) không chặn app nạp.
- `GuestStore` quản lý kho app và đóng gói app vào iDesk. Nó cũng chép sang Info.plist của iDesk những gì iOS chỉ đọc
  từ app đã cài: lời xin quyền, bảo mật mạng (ATS), chế độ nền và URL scheme.
- `GuestRuntime` chạy chính `main()` của app tới `UIApplicationMain` để biết app delegate, rồi chạy vòng đời app và
  scene (app UIKit lẫn SwiftUI). Mọi cửa sổ app tạo ra (cửa sổ chính thứ hai, lớp phủ, HUD) được nhận diện là của
  app đó qua ngăn xếp lệnh gọi, giữ dưới cửa sổ của iDesk trên iPhone, và hiện trong cửa sổ desktop của app qua
  `_UIPortalView`.
- `GuestShims` sửa những gì app nào nằm trong iDesk cũng gặp, không riêng app nào:
  - app chạy với quyền (entitlement) của iDesk: bỏ nhóm keychain riêng, cấp thư mục riêng cho App Group bị thiếu,
    đưa CloudKit một đối tượng rỗng thay thế, trả lời "từ chối" cho yêu cầu HealthKit;
  - tiến trình đã khởi chạy từ trước: chặn `UIApplicationMain`, nhận đăng ký `BGTaskScheduler` mà không crash, đăng
    ký font của app;
  - tiến trình là của iDesk và dùng chung cho nhiều app: `Bundle.main`, `CFBundleGetMainBundle`,
    `UIApplication.delegate`, `keyWindow` và `windows` trả về đúng của từng app, nhận ra qua ngăn xếp lệnh gọi; app
    tự gọi `exit()` thì được ghi vào báo lỗi.
- `CategoryRepair` thêm hàm đọc/ghi còn thiếu cho thuộc tính `@dynamic` mà app khai báo trên `CALayer` /
  `CAAnimation` (AsyncDisplayKit trong YouTube làm vậy).
- `GuestTouch` tạo chạm giả (UITouch + IOHIDEvent), cuộn và gõ chữ vào app.
- `CrashReporter` ghi lại tín hiệu, ngoại lệ chưa xử lý, ngoại lệ Mach, và ghi "nhịp tim" để biết khi iOS tắt iDesk
  (hết RAM).
- `CodeSigner` ký mã ngay trên iPhone cho mục **Nâng cao**.

## Phát triển

### Thử không cần màn hình ngoài hay iPhone

- Tham số khởi chạy `-iDeskPreview` hiện desktop trên màn hình iPhone, chạm trực tiếp được (giữ lâu = chuột phải).
  Thêm
  `-iDeskInstall <đường dẫn .ipa> [ipa khác…]` để cài các app và mở app đầu tiên, hoặc `-iDeskOpen <địa chỉ>` để mở trang web.
- Simulator không chạy được app build cho máy thật, nhưng trên Mac chip Apple mã là một. Chuyển IPA đã giải mã rồi
  đưa file `-sim.ipa` vào `-iDeskInstall`:

  ```bash
  scripts/sim-ipa.sh App.ipa
  ```

  Simulator không phát được video.

### Dịch

Toàn bộ chữ nằm trong `iDesk/Localizable.xcstrings`, lời xin quyền nằm trong `iDesk/InfoPlist.xcstrings`. Mở bằng
Xcode và thêm ngôn ngữ để dịch iDesk.

### Cấu trúc

```
iDesk/
  App/          app delegate, scene iPhone và màn hình ngoài, chế độ xem thử
  Desktop/      trạng thái và giao diện desktop, nhập liệu web, toàn màn hình web
  Controller/   màn hình iPhone: trackpad, bàn phím, bảng app, cài đặt
  Input/        chuột (GameController, AssistiveTouch)
  Guest/        chạy app từ file IPA (xem "Cách hoạt động")
  Localizable.xcstrings, InfoPlist.xcstrings
scripts/        build-ipa.sh, sim-ipa.sh
.github/        build tự động, phát hành (đẩy tag như v0.2.0), mẫu báo lỗi
project.yml     cấu hình XcodeGen
```

## Lỗi đã biết

- Trang web nhận sự kiện chuột qua JavaScript nên kiểu CSS `:hover` không áp dụng, và một số trang (app vẽ bằng
  canvas, khung nhúng từ trang khác) có thể không nhận nhấp.
- Gõ trực tiếp không hỗ trợ bộ gõ ghép chữ; gõ tiếng Việt, tiếng Nhật, tiếng Trung… thì dùng ô soạn chữ.
- Chưa cắm màn hình ngoài thì chỉ quản lý app và chứng chỉ được.

## Hỏi đáp

**iDesk có hiện được app đã cài sẵn trên iPhone không?** Không. iOS nhốt mỗi app trong hộp cát (sandbox) riêng:
không app nào nhìn thấy, hiển thị hay điều khiển được app khác, và không có API nào làm việc đó. iDesk chỉ hiện được
trang web hoặc nạp mã của app từ file IPA. Muốn dùng app đã cài trên màn hình ngoài thì cần iPad có Stage Manager.

## Giấy phép

[MIT](LICENSE)

## Lưu ý

Chỉ nạp app mà bạn có quyền sử dụng. iDesk không liên quan tới Apple, Google hay nhà phát triển app nào.
