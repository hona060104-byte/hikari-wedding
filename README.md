# HIKARI WEDDING — bản khởi tạo đa nền tảng

Đây là bộ mã nguồn khởi tạo ứng dụng PWA dùng chung cho iPhone và Android.

## Đã có trong bộ khung
- Giao diện thương hiệu HIKARI WEDDING.
- PWA manifest, icon và service worker cơ bản.
- Đăng nhập số điện thoại bằng OTP qua Supabase Auth (cần cấu hình nhà cung cấp SMS).
- Khung phân vai `owner`, `staff`, `customer`.
- Khung giao diện riêng cho nội bộ và khách hàng.
- Schema dữ liệu ban đầu: hồ sơ, khách hàng, gói, hợp đồng, trang phục, phiếu thuê, tệp và thanh toán.
- RLS cơ bản để khách chỉ đọc hồ sơ/phiếu thuê/tệp/thanh toán của chính mình.
- Hàm báo giá phía database: khách chỉ nhận giá theo nhóm của mình; nhân viên/chủ có thể yêu cầu bảng giá theo nhóm.

## Quy tắc giá được mô hình hóa
- `base_package_price` là giá cơ bản dành cho khách trong gói.
- Giá khách thuê lẻ bắt đầu bằng giá cơ bản + 1.000.000đ.
- Mỗi lượt thuê đã hoàn tất làm giảm 500.000đ cho lần thuê kế tiếp.
- Khách trong gói: từ lần thuê thứ 5 trở đi miễn phí.
- Khách thuê lẻ: tiếp tục giảm đến 0đ.
- Bộ đếm `completed_rentals` là số lượt hoàn tất của chiếc váy trên toàn hệ thống, không chia riêng theo nhóm.
- QR chỉ nên chứa mã/ID váy; giá phải được lấy sau khi xác thực tài khoản và phân quyền.

## Cần làm trước khi sử dụng thật
Bộ mã này **chưa phải ứng dụng đã triển khai**, chưa có database online, số điện thoại chủ, tài khoản nhân viên/khách hay SMS OTP hoạt động. Cần hoàn thành:
1. Tạo dự án Supabase.
2. Bật Phone Auth và cấu hình nhà cung cấp SMS phù hợp tại Việt Nam.
3. Chạy migration SQL.
4. Tạo hồ sơ chủ đầu tiên bằng thao tác quản trị an toàn (không tự cho người đăng ký mới quyền owner).
5. Hoàn thiện Edge Function/transaction để xác nhận trả váy và tăng bộ đếm đúng một lần.
6. Bổ sung màn CRUD thực tế, tải ảnh lên storage, quét QR bằng camera, bản đồ, lịch và kiểm thử phân quyền.
7. Deploy lên hosting HTTPS để cài PWA trên điện thoại.

## Chạy thử giao diện
Yêu cầu Node.js 20+.
```bash
cp .env.example .env
# Điền VITE_SUPABASE_URL và VITE_SUPABASE_ANON_KEY
npm install
npm run dev
```

## Cài trên điện thoại sau khi deploy HTTPS
- iPhone: mở URL bằng Safari → Chia sẻ → Thêm vào Màn hình chính.
- Android: mở URL bằng Chrome → Cài đặt ứng dụng / Add to Home screen.

## Lưu ý bảo mật
Không đưa `service_role` key vào frontend. Chỉ dùng anon key trong ứng dụng. Không mở quyền xem bảng `garments` cho khách; khách chỉ nhận thông tin sản phẩm đã được gán thông qua một API/Edge Function bảo mật. Cần rà soát và kiểm thử RLS trước khi dùng dữ liệu thật.
